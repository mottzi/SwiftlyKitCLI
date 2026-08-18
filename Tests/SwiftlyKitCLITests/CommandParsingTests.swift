import ArgumentParser
import Foundation
import SwiftlyKit
import Testing
@testable import SwiftlyKitCLI

@Suite("SwiftlyKitCLI command parsing contract", .serialized)
/// Parsing, validation, and contextual conversion behavior.
struct CommandParsingTests {

    @Test
    /// Verifies representative build arguments parse and convert without running SwiftlyKit.
    func buildArgumentsAndContextualConversion() async throws {

        let package = try makePackage()
        defer { try? FileManager.default.removeItem(at: package) }
        let arguments = [
            "build", package.path, "--swift-version", "6.0.0", "--architecture", "aarch64",
            "--configuration", "debug", "--product", "Server", "--jobs", "3",
            "--trait", "FeatureA", "--include-default-traits",
            "--environment", "TOKEN", "--sensitive-environment", "SECRET",
            "--unset-environment", "REMOVE", "--environment-storage-path", "Environment",
            "--scratch-path", "Scratch", "--cache-path", "Cache",
            "--swiftpm-configuration-path", "Configuration", "--security-path", "Security",
            "--install-environment", "--removal-plan", "Removal.json",
            "--output-path", "Output", "--replace-output", "--cleanup", "reset",
            "--strip", "--resolve-dependencies", "--json"
        ]

        let parsed = try await SwiftlyKitCommand.asyncParseAsRoot(arguments)
        let command = try #require(parsed as? BuildCommand)
        let context = CLICommandContext(
            currentDirectory: package,
            environment: ["TOKEN": "plain", "SECRET": "secret", "REMOVE": "old"],
            output: RecordingCLIOutput(),
            onEvent: nil
        )

        #expect(command.packagePath == package.path)
        #expect(command.product == "Server")
        #expect(command.jobs == 3)
        #expect(command.strip)
        #expect(command.resolveDependencies)
        #expect(command.selection.target == .linux(.arm64))
        #expect(command.selection.toolchain == .exact(SwiftVersion(major: 6, minor: 0, patch: 0)))
        #expect(try command.selection.environmentStorage(in: context) == .directory(package.appending(path: "Environment")))
        #expect(command.scratch.storage(in: context) == .directory(package.appending(path: "Scratch")))
        #expect(command.cliOutput.json)
        #expect(!command.cliOutput.verbose)
        guard case .debug = command.configuration?.value else {
            Issue.record("The parsed build must use debug configuration.")
            return
        }
        _ = try command.preparation.swiftPMTraits
        _ = try command.preparation.swiftPMEnvironment(in: context)
    }

    @Test
    /// Verifies each declared subcommand parses without invoking its operation.
    func everySubcommandParsesWithoutExecution() async throws {

        let forms = [
            ["host-readiness"],
            ["install-command-line-tools"],
            ["environments"],
            ["assess"],
            ["prepare"],
            ["products"],
            ["resolve"],
            ["build"],
            ["clean"],
            ["reset"],
            ["remove", "--swift-version", "6.0"]
        ]

        for arguments in forms {
            let parsed = try await SwiftlyKitCommand.asyncParseAsRoot(arguments)
            #expect(parsed is any SwiftlyKitCLICommand, "Not a CLI command: \(arguments)")
        }
    }

    @Test
    /// Verifies native ArgumentParser validation rejects command-level relationships before execution.
    func argumentParserValidationRejectsInvalidForms() async {

        let forms = [
            ["build", "--verbose", "--json"],
            ["remove", "--swift-version", "6.0", "--verbose", "--json"],
            ["build", "--jobs", "0"],
            ["build", "--architecture", "arm64"],
            ["build", "--architecture", "amd64"],
            ["build", "--configuration", "optimized"],
            ["build", "--trait", "Feature", "--no-traits"],
            ["build", "--trait", "Feature", "--all-traits"],
            ["build", "--include-default-traits"],
            ["build", "--cleanup", "clean"],
            ["build", "--replace-output"],
            ["remove", "Removal.json", "--swift-version", "6.0"]
        ]

        for arguments in forms {
            do {
                _ = try await SwiftlyKitCommand.asyncParseAsRoot(arguments)
                Issue.record("Invalid arguments parsed successfully: \(arguments)")
            } catch {
                #expect(!SwiftlyKitCommand.exitCode(for: error).isSuccess)
            }
        }
    }

    @Test
    /// Verifies contextual environment conversion reports duplicate and missing process variables.
    func contextualEnvironmentConversionRejectsInvalidValues() async throws {

        let duplicate = try await parsedBuild(["build", "--environment", "TOKEN", "--environment", "TOKEN"])
        let missing = try await parsedBuild(["build", "--environment", "MISSING"])
        let invalidName = try await parsedBuild(["build", "--environment", "1TOKEN"])
        let invalidSpelling = try await parsedBuild(["build", "--environment", "TOKEN=bad"])
        let context = CLICommandContext(
            currentDirectory: URL(filePath: "/tmp"),
            environment: ["TOKEN": "value", "1TOKEN": "value", "TOKEN=bad": "value"],
            output: RecordingCLIOutput(),
            onEvent: nil
        )

        do {
            _ = try duplicate.preparation.swiftPMEnvironment(in: context)
            Issue.record("Duplicate environment names were accepted.")
        } catch let error as CLIInputError {
            guard case .duplicateEnvironment("TOKEN") = error else {
                Issue.record("Unexpected duplicate-environment error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected duplicate-environment error: \(error)")
        }

        do {
            _ = try missing.preparation.swiftPMEnvironment(in: context)
            Issue.record("Missing environment values were accepted.")
        } catch let error as CLIInputError {
            guard case .missingEnvironmentValue("MISSING") = error else {
                Issue.record("Unexpected missing-environment error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected missing-environment error: \(error)")
        }

        for command in [invalidName, invalidSpelling] {
            do {
                _ = try command.preparation.swiftPMEnvironment(in: context)
                Issue.record("Invalid environment names were accepted.")
            } catch let error as SwiftlyKitError {
                guard case .invalidSwiftPMEnvironmentVariable = error else {
                    Issue.record("Unexpected invalid-environment error: \(error)")
                    continue
                }
            } catch {
                Issue.record("Unexpected invalid-environment error: \(error)")
            }
        }
    }

    @Test
    /// Verifies package-root validation happens before contextual environment conversion.
    func packageValidationPrecedesEnvironmentValidation() async throws {

        let parsed = try await SwiftlyKitCommand.asyncParseAsRoot([
            "build", "missing", "--environment", "MISSING"
        ])
        let command = try #require(parsed as? BuildCommand)
        let context = CLICommandContext(
            currentDirectory: URL(filePath: "/tmp/swiftlykitcli-missing-package"),
            environment: [:],
            output: RecordingCLIOutput(),
            onEvent: nil
        )

        do {
            _ = try await command.execute(in: context)
            Issue.record("The invalid package root was accepted.")
        } catch let error as SwiftlyKitError {
            guard case .invalidPackageRoot = error else {
                Issue.record("Unexpected SwiftlyKit error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

}

private func parsedBuild(_ arguments: [String]) async throws -> BuildCommand {
    let parsed = try await SwiftlyKitCommand.asyncParseAsRoot(arguments)
    return try #require(parsed as? BuildCommand)
}
