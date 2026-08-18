import ArgumentParser
import SwiftlyKit

/// Lists exact environments compatible with a package.
struct EnvironmentsCommand: SwiftlyKitCLICommand {

    @Argument(help: "Package root containing Package.swift.")
    var packagePath: String?

    @OptionGroup var selection: CLIEnvironmentSelectionOptions
    @OptionGroup var output: CLIOutputOptions

    var cliOutput: CLIOutputMode { CLIOutputMode(json: output.json) }

    func execute(in context: CLICommandContext) async throws -> CLIResult {

        let packageRoot = try context.packageRoot(packagePath)
        let swiftlyKit = SwiftlyKit(
            environmentStorage: try selection.environmentStorage(in: context)
        )
        let choices = try await swiftlyKit.compatibleEnvironments(
            packageRoot,
            for: selection.target
        )
        return .environments(choices.map(CLIEnvironmentSummary.init))
    }

    static let configuration = CommandConfiguration(
        commandName: "environments",
        abstract: "List compatible Swift environments."
    )

}
