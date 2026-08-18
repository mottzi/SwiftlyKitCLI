import ArgumentParser
import SwiftlyKit

/// Assesses one exact environment without changing state.
struct AssessCommand: SwiftlyKitCLICommand {

    @Argument(help: "Package root containing Package.swift.")
    var packagePath: String?

    @OptionGroup var selection: CLIExactEnvironmentOptions
    @OptionGroup var output: CLIOutputOptions

    var cliOutput: CLIOutputMode { CLIOutputMode(json: output.json) }

    func execute(in context: CLICommandContext) async throws -> CLIResult {

        let packageRoot = try context.packageRoot(packagePath)
        let swiftlyKit = SwiftlyKit(
            environmentStorage: try selection.environmentStorage(in: context)
        )
        let assessment = try await swiftlyKit.assess(
            packageRoot,
            for: selection.target,
            toolchain: selection.toolchain
        )
        return .assessment(CLIEnvironmentSummary(assessment))
    }

    static let configuration = CommandConfiguration(
        commandName: "assess",
        abstract: "Assess the selected Swift environment."
    )

}
