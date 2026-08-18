import ArgumentParser
import Foundation

/// Argument parsing and process-channel orchestration for one invocation.
public struct SwiftlyKitCLIRuntime: Sendable {

    private let version: String
    private let environment: [String: String]
    private let currentDirectory: URL

    /// Creates a runtime with the live process dependencies.
    public init(
        version: String = "0.1.0",
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectory: URL = URL(filePath: FileManager.default.currentDirectoryPath)
    ) {
        self.version = version
        self.environment = environment
        self.currentDirectory = currentDirectory
    }

    /// Executes one argument vector and returns its stable process status.
    public func run(arguments: [String], output: any CLIOutputWriting) async -> Int32 {

        let renderer = CLIRenderer()

        if arguments == ["--version"] {
            output.writeStandardOutput("SwiftlyKitCLI \(version)\n")
            return 0
        }

        if arguments.isEmpty {
            output.writeStandardError(SwiftlyKitCommand.helpMessage(columns: 100))
            return 2
        }

        var didParseCommand = false
        do {
            var parsed = try await SwiftlyKitCommand.asyncParseAsRoot(arguments)
            didParseCommand = true
            if let command = parsed as? any SwiftlyKitCLICommand {
                let context = CLICommandContext(
                    currentDirectory: currentDirectory,
                    environment: environment,
                    output: output,
                    onEvent: nil
                )
                return await CLICommandRunner.run(command, in: context)
            }

            try parsed.run()
            return 0
        } catch {
            if didParseCommand,
               SwiftlyKitCommand.exitCode(for: error) == .success,
               let helpError = await helpTargetError(in: arguments) {
                return renderParserError(
                    helpError,
                    arguments: arguments,
                    output: output,
                    renderer: renderer
                )
            }
            return renderParserError(
                error,
                arguments: arguments,
                output: output,
                renderer: renderer
            )
        }
    }

}

extension SwiftlyKitCLIRuntime {

    /// ArgumentParser accepts arbitrary names after its built-in `help` command.
    /// Reparse the target through the real command tree so unknown help targets
    /// retain the normal usage failure instead of silently showing root help.
    private func helpTargetError(in arguments: [String]) async -> Error? {

        guard arguments.first == "help", arguments.count > 1 else { return nil }
        do {
            _ = try await SwiftlyKitCommand.asyncParseAsRoot(Array(arguments.dropFirst()))
            return nil
        } catch {
            return error
        }
    }

    private func renderParserError(
        _ error: Error,
        arguments: [String],
        output: any CLIOutputWriting,
        renderer: CLIRenderer
    ) -> Int32 {

        let exitCode = SwiftlyKitCommand.exitCode(for: error)
        if exitCode == .success {
            output.writeStandardOutput(
                SwiftlyKitCommand.fullMessage(for: error, columns: 100)
            )
            return 0
        }

        let detail = SwiftlyKitCommand.message(for: error)
        return renderer.renderUsage(
            detail: detail.isEmpty ? error.localizedDescription : detail,
            command: commandName(from: arguments),
            json: arguments.contains("--json"),
            output: output
        )
    }

    private func commandName(from arguments: [String]) -> String {
        arguments.first(where: { !$0.hasPrefix("-") }) ?? "swiftlykit"
    }

}
