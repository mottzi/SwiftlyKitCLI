import Darwin
import Foundation

/// Serialized stdout and stderr boundary used by the command runtime.
public protocol CLIOutputWriting: Sendable {

    /// Whether standard error is connected to an interactive terminal.
    var standardErrorIsTTY: Bool { get }

    /// Writes one complete value to standard output.
    func writeStandardOutput(_ value: String)

    /// Writes one complete value to standard error.
    func writeStandardError(_ value: String)

}

extension CLIOutputWriting {

    /// Defaults injected output to deterministic noninteractive rendering.
    public var standardErrorIsTTY: Bool { false }

}

/// FileHandle-backed process output for the standalone executable.
public final class FileHandleCLIOutput: CLIOutputWriting, @unchecked Sendable {

    private let standardOutput: FileHandle
    private let standardError: FileHandle
    private let lock = NSLock()

    /// Creates an output adapter for the supplied process channels.
    public init(standardOutput: FileHandle = .standardOutput, standardError: FileHandle = .standardError) {
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    /// Whether the process standard-error descriptor is an interactive terminal.
    public var standardErrorIsTTY: Bool { isatty(STDERR_FILENO) == 1 }

    /// Writes one UTF-8 value to standard output.
    public func writeStandardOutput(_ value: String) {
        lock.withLock { try? standardOutput.write(contentsOf: Data(value.utf8)) }
    }

    /// Writes one UTF-8 value to standard error.
    public func writeStandardError(_ value: String) {
        lock.withLock { try? standardError.write(contentsOf: Data(value.utf8)) }
    }

}
