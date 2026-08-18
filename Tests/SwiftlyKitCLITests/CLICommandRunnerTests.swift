import ArgumentParser
import Foundation
import SwiftlyKit
import Testing
@testable import SwiftlyKitCLI

@Suite("SwiftlyKitCLI command runner contract", .serialized)
/// Rendering, status, and cancellation behavior at the command-runner seam.
struct CLICommandRunnerTests {

    @Test
    /// Verifies stable status classes for representative SwiftlyKit failures at the runner seam.
    func failureCategoriesMapToStableStatuses() async {

        let failures: [(SwiftlyKitError, Int32, String)] = [
            (.invalidPackageRoot(URL(filePath: "/missing")), 2, "invalidPackageRoot"),
            (.developerToolsUnavailable, 4, "developerToolsUnavailable"),
            (.buildArtifactCleanupFailed("failed"), 4, "buildArtifactCleanupFailed"),
            (.buildStorageResetFailed("failed"), 4, "buildStorageResetFailed"),
            (.environmentRemovalFailed("failed"), 4, "environmentRemovalFailed"),
            (.runtimeResourceVerificationFailed, 6, "runtimeResourceVerificationFailed"),
            (.buildFailed("failed"), 5, "buildFailed"),
            (.executableVerificationFailed("failed"), 6, "executableVerificationFailed"),
            (.mutationCoordinationFailed("busy"), 7, "mutationCoordinationFailed")
        ]

        for (failure, expectedStatus, expectedCode) in failures {
            let output = RecordingCLIOutput()
            let status = await runTestCommand(
                command: makeTestCommand(json: true),
                output: output
            ) { _ in
                throw failure
            }

            #expect(status == expectedStatus)
            #expect(output.standardError.isEmpty)
            #expect(output.standardOutput.filter { $0 == "\n" }.count == 1)
            #expect(output.standardOutput.contains("\"code\":\"\(expectedCode)\""))
        }
    }

    @Test
    /// Verifies an unexpected command failure maps to the internal status.
    func unexpectedFailureMapsToStatusOne() async {

        let output = RecordingCLIOutput()
        let status = await runTestCommand(
            command: makeTestCommand(json: true),
            output: output
        ) { _ in
            throw TestInternalError()
        }

        #expect(status == 1)
        #expect(output.standardError.isEmpty)
        #expect(output.standardOutput.contains("\"code\":\"internal\""))
    }

    @Test
    /// Verifies human success uses stdout and JSON success emits one compact envelope.
    func successChannelsRemainExclusive() async {

        for json in [false, true] {
            let output = RecordingCLIOutput()
            let status = await runTestCommand(
                command: makeTestCommand(json: json),
                output: output
            ) { _ in
                .hostReadiness(.ready)
            }

            #expect(status == 0)
            #expect(output.standardError.isEmpty)
            #expect(output.standardOutput.filter { $0 == "\n" }.count == 1)
            if json {
                #expect(output.standardOutput.contains("\"schemaVersion\":1"))
                #expect(output.standardOutput.contains("\"outcome\":\"success\""))
            } else {
                #expect(output.standardOutput == "Host readiness: ready\n")
            }
        }
    }

    @Test
    /// Verifies preparation-required results use status three and the correct output channel.
    func preparationRequiredUsesHumanAndJSONContracts() async throws {

        let package = try makePackage()
        defer { try? FileManager.default.removeItem(at: package) }
        let summary = CLIEnvironmentSummary(
            packageRoot: package,
            toolsVersion: SwiftVersion(major: 6, minor: 0, patch: 0),
            swiftVersion: SwiftVersion(major: 6, minor: 0, patch: 0),
            staticLinuxSDKIdentifier: "swift-6.0.0-RELEASE_static-linux",
            staticLinuxSDKVersion: "6.0.0",
            requiredComponents: [.swiftly, .toolchain, .staticLinuxSDK],
            isSwiftlyAvailable: false,
            isToolchainAvailable: false,
            isStaticLinuxSDKAvailable: false,
            requiresInstallation: true
        )

        for json in [false, true] {
            let output = RecordingCLIOutput()
            let status = await runTestCommand(
                command: makeTestCommand(json: json),
                output: output
            ) { _ in
                .preparationRequired(summary)
            }

            #expect(status == 3)
            #expect(output.standardOutput.isEmpty == !json)
            #expect(output.standardError.isEmpty == json)
            if json {
                #expect(output.standardOutput.filter { $0 == "\n" }.count == 1)
                let data = try #require(output.standardOutput.data(using: .utf8))
                let document = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
                #expect(document["schemaVersion"] as? Int == 1)
                #expect(document["outcome"] as? String == "preparationRequired")
            } else {
                #expect(output.standardError.contains("action required:"))
                #expect(output.standardError.contains("--install-environment"))
            }
        }
    }

    @Test
    /// Verifies cancellation uses status 130 and one terminal JSON or human outcome.
    func cancellationHasOneTerminalOutcome() async {

        for json in [false, true] {
            let output = RecordingCLIOutput()
            let status = await runTestCommand(
                command: makeTestCommand(json: json),
                output: output
            ) { _ in
                throw CancellationError()
            }

            #expect(status == 130)
            #expect(output.standardOutput.isEmpty == !json)
            #expect(output.standardError.isEmpty == json)
            #expect(output.standardOutput.filter { $0 == "\n" }.count == (json ? 1 : 0))
            if !json {
                #expect(output.standardError.contains("cancelled: Operation cancelled."))
            }
        }
    }

}

private func makeTestCommand(json: Bool = false, verbose: Bool = false) -> TestCLICommand {

    var command = TestCLICommand()
    command.json = json
    command.verbose = verbose
    return command
}

private func runTestCommand(
    command: TestCLICommand,
    output: RecordingCLIOutput,
    body: @escaping @Sendable (CLICommandContext) async throws -> CLIResult
) async -> Int32 {

    let context = CLICommandContext(
        currentDirectory: URL(filePath: "/tmp"),
        environment: [:],
        output: output,
        onEvent: nil
    )
    return await TestCommandBehavior.$body.withValue(body) {
        await CLICommandRunner.run(command, in: context)
    }
}

/// A small test-only command adapter for exercising the runner without SwiftlyKit state.
private struct TestCLICommand: SwiftlyKitCLICommand {

    @Flag var json = false
    @Flag var verbose = false

    var cliCommandName: String { "test" }
    var cliOutput: CLIOutputMode { CLIOutputMode(verbose: verbose, json: json) }

    func execute(in context: CLICommandContext) async throws -> CLIResult {
        try await TestCommandBehavior.body(context)
    }

    static let configuration = CommandConfiguration(commandName: "test")

}

private enum TestCommandBehavior {

    @TaskLocal
    static var body: @Sendable (CLICommandContext) async throws -> CLIResult = { _ in
        .hostReadiness(.ready)
    }

}

/// Unexpected failure used to verify the catastrophic status mapping.
private struct TestInternalError: Error, Sendable {}
