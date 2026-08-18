import Foundation
import SwiftlyKitCLI

@main
/// Process entry point for the standalone swiftlykit executable.
enum SwiftlyKitCLIEntryPoint {

    /// Runs one invocation against the live SwiftlyKit adapter.
    static func main() async {
        let runtime = SwiftlyKitCLIRuntime()
        let status = await runtime.run(
            arguments: Array(CommandLine.arguments.dropFirst()),
            output: FileHandleCLIOutput()
        )
        exit(status)
    }

}
