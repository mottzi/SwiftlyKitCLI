import Foundation
import SwiftlyKit
import ArgumentParser

/// JSON output control for read-only commands.
struct CLIOutputOptions: ParsableArguments, Sendable {

    @Flag(name: .long, help: "Emit one compact machine-readable result.")
    var json = false

}

/// Human verbosity and JSON controls for operations that emit SwiftlyKit events.
struct CLIVerboseOutputOptions: ParsableArguments, Sendable {

    @Flag(name: .long, help: "Show commands and raw tool output.")
    var verbose = false

    @Flag(name: .long, help: "Emit one compact machine-readable result.")
    var json = false

    var cliOutput: CLIOutputMode { CLIOutputMode(verbose: verbose, json: json) }

    mutating func validate() throws {
        guard !(verbose && json) else {
            throw ValidationError("--verbose and --json are mutually exclusive.")
        }
    }

}

/// Target and environment namespace selection shared by read-only commands.
struct CLIEnvironmentSelectionOptions: ParsableArguments, Sendable {

    @Option(name: .customLong("architecture"), help: "Linux architecture: x86_64 or aarch64.")
    var architecture: CLIArchitecture?

    @Option(name: .customLong("environment-storage-path"), help: "Custom Swiftly environment storage directory.")
    var environmentStoragePath: String?

    var target: BuildTarget { .linux((architecture ?? .x86_64).value) }

    func environmentStorage(in context: CLICommandContext) throws -> EnvironmentStorage {
        guard let environmentStoragePath else { return .standard }
        return .directory(context.canonicalURL(environmentStoragePath))
    }

}

/// Exact Swift selection shared by assessment and build commands.
struct CLIExactEnvironmentOptions: ParsableArguments, Sendable {

    @Option(name: .customLong("swift-version"), help: "Exact Swift release, such as 6.0 or 6.0.0.")
    var swiftVersion: CLISwiftVersionArgument?

    @Option(name: .customLong("architecture"), help: "Linux architecture: x86_64 or aarch64.")
    var architecture: CLIArchitecture?

    @Option(name: .customLong("environment-storage-path"), help: "Custom Swiftly environment storage directory.")
    var environmentStoragePath: String?

    var target: BuildTarget { .linux((architecture ?? .x86_64).value) }
    var toolchain: ToolchainSelection { swiftVersion.map { .exact($0.value) } ?? .automatic }

    func environmentStorage(in context: CLICommandContext) throws -> EnvironmentStorage {
        guard let environmentStoragePath else { return .standard }
        return .directory(context.canonicalURL(environmentStoragePath))
    }

}

/// Environment preparation controls shared by mutating package commands.
struct CLIPreparationOptions: ParsableArguments, Sendable {

    @Option(name: .customLong("trait"), help: "Explicit package trait; repeat for multiple traits.")
    var traits: [String] = []

    @Flag(name: .customLong("no-traits"), help: "Disable package default traits.")
    var noTraits = false

    @Flag(name: .customLong("all-traits"), help: "Enable all package traits.")
    var allTraits = false

    @Flag(name: .customLong("include-default-traits"), help: "Include package defaults with explicit traits.")
    var includeDefaultTraits = false

    @Option(name: .customLong("environment"), help: "Import a named process variable; repeat as needed.")
    var environmentNames: [String] = []

    @Option(name: .customLong("sensitive-environment"), help: "Import and redact a named process variable.")
    var sensitiveEnvironmentNames: [String] = []

    @Option(name: .customLong("unset-environment"), help: "Remove an inherited process variable.")
    var unsetEnvironmentNames: [String] = []

    @Option(name: .customLong("cache-path"), help: "Custom SwiftPM cache directory.")
    var cachePath: String?

    @Option(name: .customLong("swiftpm-configuration-path"), help: "Custom SwiftPM configuration directory.")
    var swiftPMConfigurationPath: String?

    @Option(name: .customLong("security-path"), help: "Custom SwiftPM security directory.")
    var securityPath: String?

    @Flag(name: .customLong("install-environment"), help: "Install required Swiftly, toolchain, and SDK components.")
    var installEnvironment = false

    @Option(name: .customLong("removal-plan"), help: "Record the latest environment removal plan at this path.")
    var removalPlanPath: String?

    mutating func validate() throws {

        guard !(noTraits && allTraits),
              !(noTraits && !traits.isEmpty),
              !(allTraits && !traits.isEmpty)
        else { throw ValidationError("The trait flags are mutually exclusive.") }
        
        guard !includeDefaultTraits || !traits.isEmpty
        else { throw ValidationError("--include-default-traits requires at least one --trait.") }
    }

}

/// SwiftPM scratch and shared-storage controls for staged package operations.
struct CLIScratchOptions: ParsableArguments, Sendable {

    @Option(name: .customLong("scratch-path"), help: "Custom SwiftPM scratch directory.")
    var scratchPath: String?

    func storage(in context: CLICommandContext) -> SwiftPMScratchStorage {
        guard let scratchPath else { return .packageDefault }
        return .directory(context.canonicalURL(scratchPath))
    }

}
