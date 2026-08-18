import ArgumentParser
import SwiftlyKit

/// Requests Apple's interactive Command Line Tools installer.
struct InstallCommandLineToolsCommand: SwiftlyKitCLICommand {

    @OptionGroup var output: CLIOutputOptions

    var cliOutput: CLIOutputMode { CLIOutputMode(json: output.json) }

    func execute(in context: CLICommandContext) async throws -> CLIResult {
        try await SwiftlyKit.requestCommandLineToolsInstallation()
        return .commandLineToolsInstallation
    }

    static let configuration = CommandConfiguration(
        commandName: "install-command-line-tools",
        abstract: "Request installation of Apple's Command Line Tools."
    )

}
