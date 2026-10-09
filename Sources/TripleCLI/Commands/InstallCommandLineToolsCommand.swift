import ArgumentParser
import Triple

/// Requests Apple's interactive Command Line Tools installer.
struct InstallCommandLineToolsCommand: TripleCLICommand {

    @OptionGroup var output: CLIOutputOptions

    func execute(in context: CLICommandContext) async throws -> CLIResult {
        try await Triple.requestCommandLineToolsInstallation()
        return .commandLineToolsInstallation
    }

    var cliOutput: CLIOutputMode { CLIOutputMode(json: output.json) }

    static let configuration = CommandConfiguration(
        commandName: "install-command-line-tools",
        abstract: "Request installation of Apple's Command Line Tools."
    )

}
