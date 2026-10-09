import Foundation
import TripleCLI

@main
/// Process entry point for the standalone triple executable.
enum TripleCLIEntryPoint {

    /// Runs one invocation against live Triple services.
    static func main() async {
        let runtime = TripleCLIRuntime()
        let status = await runtime.run(
            arguments: Array(CommandLine.arguments.dropFirst()),
            output: FileHandleCLIOutput()
        )
        exit(status)
    }

}
