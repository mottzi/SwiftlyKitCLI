import Darwin
import Foundation

/// Standard-output and standard-error interface for command execution.
public protocol CLIOutputWriting: Sendable {

    /// Whether standard error is connected to an interactive terminal.
    var standardErrorIsTTY: Bool { get }

    /// Writes text to standard output.
    func writeStandardOutput(_ value: String)

    /// Writes text to standard error.
    func writeStandardError(_ value: String)

}

extension CLIOutputWriting {

    /// Reports standard error as noninteractive by default.
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

    /// Writes UTF-8 text to standard output.
    public func writeStandardOutput(_ value: String) {
        lock.withLock { try? standardOutput.write(contentsOf: Data(value.utf8)) }
    }

    /// Writes UTF-8 text to standard error.
    public func writeStandardError(_ value: String) {
        lock.withLock { try? standardError.write(contentsOf: Data(value.utf8)) }
    }

}
