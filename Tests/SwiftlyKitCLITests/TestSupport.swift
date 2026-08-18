import Foundation
@testable import SwiftlyKitCLI

/// Lock-protected capture of the CLI's two process output channels.
final class RecordingCLIOutput: CLIOutputWriting, @unchecked Sendable {

    private let lock = NSLock()
    private var recordedStandardOutput = ""
    private var recordedStandardError = ""

    var standardOutput: String {
        lock.withLock { recordedStandardOutput }
    }

    var standardError: String {
        lock.withLock { recordedStandardError }
    }

    func writeStandardOutput(_ value: String) {
        lock.withLock { recordedStandardOutput += value }
    }

    func writeStandardError(_ value: String) {
        lock.withLock { recordedStandardError += value }
    }

}

/// Creates a temporary readable package root for command tests.
func makePackage() throws -> URL {

    let package = FileManager.default.temporaryDirectory
        .appending(path: "SwiftlyKitCLI-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
    try Data("// swift-tools-version: 6.0\n".utf8)
        .write(to: package.appending(path: "Package.swift"))
    return package.standardizedFileURL
}
