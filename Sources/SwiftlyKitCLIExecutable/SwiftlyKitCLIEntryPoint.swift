import Foundation
import SwiftlyKitCLI

@main
/// Process entry point for the standalone swiftlykit executable.
enum SwiftlyKitCLIEntryPoint {

    /// Runs one invocation against live SwiftlyKit services.
    static func main() async {
        let runtime = SwiftlyKitCLIRuntime()
        let status = await runtime.run(
            arguments: Array(CommandLine.arguments.dropFirst()),
            output: FileHandleCLIOutput()
        )
        exit(status)
    }

}
