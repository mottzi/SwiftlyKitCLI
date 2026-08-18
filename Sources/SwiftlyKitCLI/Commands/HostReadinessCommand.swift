import ArgumentParser
import SwiftlyKit

/// Reports whether the host can run SwiftlyKit operations.
struct HostReadinessCommand: SwiftlyKitCLICommand {

    @OptionGroup var output: CLIOutputOptions

    var cliOutput: CLIOutputMode { CLIOutputMode(json: output.json) }

    func execute(in context: CLICommandContext) async throws -> CLIResult {
        .hostReadiness(try await SwiftlyKit.hostReadiness())
    }

    static let configuration = CommandConfiguration(
        commandName: "host-readiness",
        abstract: "Check host developer-tool readiness."
    )

}
