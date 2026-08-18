import ArgumentParser
import Foundation
import SwiftlyKit

/// The output mode selected by one parsed command.
struct CLIOutputMode: Sendable {

    private(set) var verbose = false
    private(set) var json = false

}

/// Immutable dependencies and process state for one command execution.
struct CLICommandContext: Sendable {

    let currentDirectory: URL
    let environment: [String: String]
    let output: any CLIOutputWriting
    let onEvent: SwiftlyKitEvent.Handler?

    /// Returns a context with the event handler supplied by the runner.
    func withEventHandler(_ onEvent: SwiftlyKitEvent.Handler?) -> CLICommandContext {

        CLICommandContext(
            currentDirectory: currentDirectory,
            environment: environment,
            output: output,
            onEvent: onEvent
        )
    }

    /// Resolves a path relative to the invocation's captured current directory.
    func canonicalURL(_ path: String) -> URL {
        let url = path.hasPrefix("/") ? URL(filePath: path) : currentDirectory.appending(path: path)
        return url.resolvingSymlinksInPath().standardizedFileURL
    }

    /// Validates and resolves a package root, defaulting to the current directory.
    func packageRoot(_ path: String?) throws -> URL {

        let root = path.map(canonicalURL) ?? canonicalURL(currentDirectory.path(percentEncoded: false))
        let manifest = root.appending(path: "Package.swift")
        
        var rootIsDirectory: ObjCBool = false
        let rootExists = FileManager.default.fileExists(
            atPath: root.path(percentEncoded: false),
            isDirectory: &rootIsDirectory
        )
        
        guard rootExists,
              rootIsDirectory.boolValue
        else { throw SwiftlyKitError.invalidPackageRoot(root) }

        var manifestIsDirectory: ObjCBool = false
        let manifestExists = FileManager.default.fileExists(
            atPath: manifest.path(percentEncoded: false),
            isDirectory: &manifestIsDirectory
        )
        
        let manifestIsReadable = FileManager.default.isReadableFile(
            atPath: manifest.path(percentEncoded: false)
        )
        
        guard manifestExists,
              !manifestIsDirectory.boolValue,
              manifestIsReadable
        else { throw SwiftlyKitError.invalidPackageRoot(root) }
        
        return root
    }

    /// Creates context for a live process invocation.
    static func live(output: any CLIOutputWriting) -> CLICommandContext {

        CLICommandContext(
            currentDirectory: URL(filePath: FileManager.default.currentDirectoryPath),
            environment: ProcessInfo.processInfo.environment,
            output: output,
            onEvent: nil
        )
    }

}

/// The one internal seam between ArgumentParser commands and process execution.
protocol SwiftlyKitCLICommand: AsyncParsableCommand, Sendable {

    var cliCommandName: String { get }
    var cliOutput: CLIOutputMode { get }

    /// Performs this command's SwiftlyKit operation and returns its terminal result.
    func execute(in context: CLICommandContext) async throws -> CLIResult

}

extension SwiftlyKitCLICommand {

    var cliCommandName: String {
        Self._commandName
    }

    /// Keeps direct ArgumentParser execution truthful while reusing process handling.
    mutating func run() async throws {
        let status = await CLICommandRunner.run(
            self,
            in: .live(output: FileHandleCLIOutput())
        )
        guard status == 0 else { throw ExitCode(status) }
    }

}
