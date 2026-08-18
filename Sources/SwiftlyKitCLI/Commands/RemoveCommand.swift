import ArgumentParser
import SwiftlyKit

/// Removes an exact Swift toolchain, SDK, or complete environment.
struct RemoveCommand: SwiftlyKitCLICommand {

    @Argument(help: "Removal-plan JSON path.")
    var removalPlanPath: String?

    @Option(name: .customLong("swift-version"), help: "Exact Swift toolchain version to remove.")
    var swiftVersion: CLISwiftVersionArgument?

    @Option(name: .customLong("sdk-identifier"), help: "Exact Static Linux SDK identifier to remove.")
    var sdkIdentifier: String?

    @Option(name: .customLong("environment-storage-path"), help: "Custom Swiftly environment storage directory.")
    var environmentStoragePath: String?

    @OptionGroup var output: CLIVerboseOutputOptions

    var cliOutput: CLIOutputMode { output.cliOutput }

    mutating func validate() throws {

        guard removalPlanPath == nil
            || (swiftVersion == nil && sdkIdentifier == nil && environmentStoragePath == nil)
        else { throw ValidationError("A removal-plan path cannot be combined with manual removal options.") }
    }

    func execute(in context: CLICommandContext) async throws -> CLIResult {

        guard removalPlanPath != nil || swiftVersion != nil || sdkIdentifier != nil
        else { throw CLIInputError.emptyRemovalSpecification }
        let plan = try removalPlan(for: self, in: context)
        try await SwiftlyKit.remove(plan, onEvent: context.onEvent)
        return .removed
    }

    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove exact Swiftly-managed environment resources."
    )

}
