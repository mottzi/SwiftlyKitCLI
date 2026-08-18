import Foundation
import SwiftlyKit

/// Coordinates one command's events, cancellation, rendering, and status.
enum CLICommandRunner {

    /// Executes one command through the supplied invocation context.
    static func run(_ command: any SwiftlyKitCLICommand, in context: CLICommandContext) async -> Int32 {

        let renderer = CLIRenderer()
        let json = command.cliOutput.json
        let verbose = command.cliOutput.verbose
        let cancellation = CLICancellationCoordinator(
            json: json,
            output: context.output,
            forceExit: { status in _exit(status) }
        )

        let invocation = Task<Int32, Never> {
            do {
                let eventHandler: SwiftlyKitEvent.Handler? = { event in
                    renderer.render(event: event, verbose: verbose, json: json, output: context.output)
                }
                let result = try await command.execute(in: context.withEventHandler(eventHandler))
                try Task.checkCancellation()
                return renderer.render(
                    result: result,
                    command: command.cliCommandName,
                    json: json,
                    output: context.output
                )
            } catch is CancellationError {
                return renderer.renderCancellation(
                    command: command.cliCommandName,
                    json: json,
                    output: context.output
                )
            } catch let error as CLIInputError {
                return renderer.renderUsage(
                    detail: error.localizedDescription,
                    command: command.cliCommandName,
                    json: json,
                    output: context.output
                )
            } catch let error as SwiftlyKitError {
                switch error {
                    case .invalidSwiftPMEnvironmentVariable, .invalidSwiftPMTrait, .invalidBuildJobCount:
                        return renderer.renderUsage(
                            detail: error.localizedDescription,
                            command: command.cliCommandName,
                            json: json,
                            output: context.output
                        )
                    default:
                        break
                }
                return renderer.render(
                    error: error,
                    command: command.cliCommandName,
                    json: json,
                    output: context.output
                )
            } catch {
                return renderer.render(
                    error: error,
                    command: command.cliCommandName,
                    json: json,
                    output: context.output
                )
            }
        }

        await cancellation.attach(invocationTask: invocation)
        let signals = CLISignalSources { Task { await cancellation.receiveSignal() } }
        signals.activate()
        defer { signals.cancel() }
        return await invocation.value
    }

}
