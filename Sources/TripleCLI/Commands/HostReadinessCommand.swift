import ArgumentParser
import Triple

/// Reports whether the host can run Triple operations.
struct HostReadinessCommand: TripleCLICommand {

    @OptionGroup var output: CLIOutputOptions

    func execute(in context: CLICommandContext) async throws -> CLIResult {
        .hostReadiness(try await Triple.hostReadiness())
    }

    var cliOutput: CLIOutputMode { CLIOutputMode(json: output.json) }

    static let configuration = CommandConfiguration(
        commandName: "host-readiness",
        abstract: "Check host developer-tool readiness."
    )

}
