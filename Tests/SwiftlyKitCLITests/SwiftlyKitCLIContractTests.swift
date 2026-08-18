import Foundation
import Testing
@testable import SwiftlyKitCLI
import SwiftlyKit

@Suite("SwiftlyKitCLI command contract")
/// Command-line help, version, and usage behavior at the runtime seam.
struct SwiftlyKitCLIContractTests {

    @Test
    /// Verifies every supported help spelling succeeds without opening SwiftlyKit.
    func everyHelpFormSucceeds() async {

        let subcommands = [
            "host-readiness",
            "install-command-line-tools",
            "environments",
            "assess",
            "prepare",
            "products",
            "resolve",
            "build",
            "clean",
            "reset",
            "remove"
        ]
        let forms = [["--help"], ["-h"]]
            + subcommands.flatMap { [["help", $0], [$0, "--help"], [$0, "-h"]] }

        for arguments in forms {
            let output = RecordingCLIOutput()
            let status = await SwiftlyKitCLIRuntime().run(arguments: arguments, output: output)

            #expect(status == 0, "Help form failed: \(arguments)")
            #expect(!output.standardOutput.isEmpty)
            #expect(output.standardError.isEmpty)
        }
    }

    @Test
    /// Verifies the root version reports the CLI release without opening SwiftlyKit.
    func rootVersionSucceeds() async {

        let output = RecordingCLIOutput()
        let runtime = SwiftlyKitCLIRuntime(version: "9.8.7")
        let status = await runtime.run(arguments: ["--version"], output: output)

        #expect(status == 0)
        #expect(output.standardOutput == "SwiftlyKitCLI 9.8.7\n")
        #expect(output.standardError.isEmpty)
    }

    @Test
    /// Verifies conventional and canonical patch-zero Swift version spellings.
    func patchZeroSwiftVersionsUseOneValue() {

        let conventional = CLISwiftVersionArgument(argument: "6.0")
        let canonical = CLISwiftVersionArgument(argument: "6.0.0")

        #expect(conventional?.value == SwiftVersion(major: 6, minor: 0, patch: 0))
        #expect(canonical?.value == SwiftVersion(major: 6, minor: 0, patch: 0))
        #expect(CLIArchitecture(rawValue: "arm64") == nil)
    }

    @Test
    /// Verifies bare and malformed invocations return the stable usage status.
    func usageFormsReturnStatusTwo() async {

        let forms = [
            [],
            ["unknown"],
            ["build", "--unknown"],
            ["build", "--version"],
            ["--version", "build"],
            ["--version", "--json"]
        ]

        for arguments in forms {
            let output = RecordingCLIOutput()
            let status = await SwiftlyKitCLIRuntime().run(arguments: arguments, output: output)

            #expect(status == 2, "Usage form returned the wrong status: \(arguments)")
            #expect(!output.standardOutput.isEmpty || !output.standardError.isEmpty)
        }
    }

}

/// Lock-protected capture of the runtime's standard output and error channels.
private final class RecordingCLIOutput: CLIOutputWriting, @unchecked Sendable {

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
