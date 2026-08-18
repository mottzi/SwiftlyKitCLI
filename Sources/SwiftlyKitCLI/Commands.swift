import ArgumentParser
import Foundation
import SwiftlyKit

/// Root command tree for the standalone SwiftlyKit command-line tool.
struct SwiftlyKitCommand: AsyncParsableCommand {

    /// Supplies the async command shape while SwiftlyKitCLIRuntime owns execution.
    mutating func run() async throws { }

    /// Root command and subcommand configuration.
    static let configuration = CommandConfiguration(
        commandName: "swiftlykit",
        abstract: "Prepare Swift environments and build verified static Linux executables.",
        subcommands: [
            HostReadinessCommand.self,
            InstallCommandLineToolsCommand.self,
            EnvironmentsCommand.self,
            AssessCommand.self,
            PrepareCommand.self,
            ProductsCommand.self,
            ResolveCommand.self,
            BuildCommand.self,
            CleanCommand.self,
            ResetCommand.self,
            RemoveCommand.self
        ]
    )

}

/// Reports whether the host can run SwiftlyKit operations.
struct HostReadinessCommand: AsyncParsableCommand {

    @OptionGroup var output: CLIOutputOptions

    /// Supplies the async command shape while SwiftlyKitCLIRuntime owns execution.
    mutating func run() async throws { }

    static let configuration = CommandConfiguration(
        commandName: "host-readiness",
        abstract: "Check host developer-tool readiness."
    )

}

/// Requests Apple's interactive Command Line Tools installer.
struct InstallCommandLineToolsCommand: AsyncParsableCommand {

    @OptionGroup var output: CLIOutputOptions

    /// Supplies the async command shape while SwiftlyKitCLIRuntime owns execution.
    mutating func run() async throws { }

    static let configuration = CommandConfiguration(
        commandName: "install-command-line-tools",
        abstract: "Request installation of Apple's Command Line Tools."
    )

}

/// Lists exact environments compatible with a package.
struct EnvironmentsCommand: AsyncParsableCommand {

    @Argument(help: "Package root containing Package.swift.")
    var packagePath: String?

    @OptionGroup var selection: CLIEnvironmentSelectionOptions
    @OptionGroup var output: CLIOutputOptions

    /// Supplies the async command shape while SwiftlyKitCLIRuntime owns execution.
    mutating func run() async throws { }

    static let configuration = CommandConfiguration(
        commandName: "environments",
        abstract: "List compatible Swift environments."
    )

}

/// Assesses one exact environment without changing state.
struct AssessCommand: AsyncParsableCommand {

    @Argument(help: "Package root containing Package.swift.")
    var packagePath: String?

    @OptionGroup var selection: CLIExactEnvironmentOptions
    @OptionGroup var output: CLIOutputOptions

    /// Supplies the async command shape while SwiftlyKitCLIRuntime owns execution.
    mutating func run() async throws { }

    static let configuration = CommandConfiguration(
        commandName: "assess",
        abstract: "Assess the selected Swift environment."
    )

}

/// Prepares one selected Swift environment.
struct PrepareCommand: AsyncParsableCommand {

    @Argument(help: "Package root containing Package.swift.")
    var packagePath: String?

    @OptionGroup var selection: CLIExactEnvironmentOptions
    @OptionGroup var preparation: CLIPreparationOptions
    @OptionGroup var output: CLIVerboseOutputOptions

    /// Supplies the async command shape while SwiftlyKitCLIRuntime owns execution.
    mutating func run() async throws { }

    static let configuration = CommandConfiguration(
        commandName: "prepare",
        abstract: "Prepare the selected Swift environment."
    )

}

/// Lists executable products from one prepared package.
struct ProductsCommand: AsyncParsableCommand {

    @Argument(help: "Package root containing Package.swift.")
    var packagePath: String?

    @OptionGroup var selection: CLIExactEnvironmentOptions
    @OptionGroup var preparation: CLIPreparationOptions
    @OptionGroup var output: CLIVerboseOutputOptions

    /// Supplies the async command shape while SwiftlyKitCLIRuntime owns execution.
    mutating func run() async throws { }

    static let configuration = CommandConfiguration(
        commandName: "products",
        abstract: "List executable package products."
    )

}

/// Resolves package dependencies in selected SwiftPM scratch storage.
struct ResolveCommand: AsyncParsableCommand {

    @Argument(help: "Package root containing Package.swift.")
    var packagePath: String?

    @OptionGroup var selection: CLIExactEnvironmentOptions
    @OptionGroup var preparation: CLIPreparationOptions
    @OptionGroup var scratch: CLIScratchOptions
    @OptionGroup var output: CLIVerboseOutputOptions

    /// Supplies the async command shape while SwiftlyKitCLIRuntime owns execution.
    mutating func run() async throws { }

    static let configuration = CommandConfiguration(
        commandName: "resolve",
        abstract: "Resolve package dependencies."
    )

}

/// Builds one verified static Linux executable.
struct BuildCommand: AsyncParsableCommand {

    @Argument(help: "Package root containing Package.swift.")
    var packagePath: String?

    @OptionGroup var selection: CLIExactEnvironmentOptions
    @OptionGroup var preparation: CLIPreparationOptions
    @OptionGroup var scratch: CLIScratchOptions
    @Option(name: .customLong("product"), help: "Executable product to build.")
    var product: String?

    @Option(name: .customLong("configuration"), help: "Build configuration: release or debug.")
    var configuration: CLIConfiguration?

    @Option(name: .long, help: "Maximum number of concurrent SwiftPM build jobs.")
    var jobs: Int?

    @Option(name: .customLong("output-path"), help: "Publish the runnable output to this directory.")
    var outputPath: String?

    @Flag(name: .customLong("replace-output"), help: "Replace an existing published output directory.")
    var replaceOutput = false

    @Option(name: .customLong("cleanup"), help: "Post-publication cleanup: retain, clean, or reset.")
    var cleanup: CLICleanup?

    @Flag(name: .customLong("strip"), help: "Strip symbols from the verified executable.")
    var strip = false

    @Flag(name: .customLong("resolve-dependencies"), help: "Resolve dependencies if the build requires it.")
    var resolveDependencies = false

    @OptionGroup var output: CLIVerboseOutputOptions

    /// Supplies the async command shape while SwiftlyKitCLIRuntime owns execution.
    mutating func run() async throws { }

    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build one verified static Linux executable."
    )

}

/// Removes compiled products and intermediate build artifacts.
struct CleanCommand: AsyncParsableCommand {

    @Argument(help: "Package root containing Package.swift.")
    var packagePath: String?

    @OptionGroup var selection: CLIExactEnvironmentOptions
    @OptionGroup var preparation: CLIPreparationOptions
    @OptionGroup var scratch: CLIScratchOptions
    @OptionGroup var output: CLIVerboseOutputOptions

    /// Supplies the async command shape while SwiftlyKitCLIRuntime owns execution.
    mutating func run() async throws { }

    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clean compiled build artifacts."
    )

}

/// Removes complete SwiftPM scratch storage.
struct ResetCommand: AsyncParsableCommand {

    @Argument(help: "Package root containing Package.swift.")
    var packagePath: String?

    @OptionGroup var selection: CLIExactEnvironmentOptions
    @OptionGroup var preparation: CLIPreparationOptions
    @OptionGroup var scratch: CLIScratchOptions
    @OptionGroup var output: CLIVerboseOutputOptions

    /// Supplies the async command shape while SwiftlyKitCLIRuntime owns execution.
    mutating func run() async throws { }

    static let configuration = CommandConfiguration(
        commandName: "reset",
        abstract: "Reset SwiftPM scratch storage."
    )

}

/// Removes an exact Swift toolchain, SDK, or complete environment.
struct RemoveCommand: AsyncParsableCommand {

    @Argument(help: "Removal-plan JSON path.")
    var removalPlanPath: String?

    @Option(name: .customLong("swift-version"), help: "Exact Swift toolchain version to remove.")
    var swiftVersion: CLISwiftVersionArgument?

    @Option(name: .customLong("sdk-identifier"), help: "Exact Static Linux SDK identifier to remove.")
    var sdkIdentifier: String?

    @Option(name: .customLong("environment-storage-path"), help: "Custom Swiftly environment storage directory.")
    var environmentStoragePath: String?

    @OptionGroup var output: CLIVerboseOutputOptions

    /// Supplies the async command shape while SwiftlyKitCLIRuntime owns execution.
    mutating func run() async throws { }

    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove exact Swiftly-managed environment resources."
    )

}

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

}

/// Target and environment namespace selection shared by read-only commands.
struct CLIEnvironmentSelectionOptions: ParsableArguments, Sendable {

    @Option(name: .customLong("architecture"), help: "Linux architecture: x86_64 or aarch64.")
    var architecture: CLIArchitecture?

    @Option(name: .customLong("environment-storage-path"), help: "Custom Swiftly environment storage directory.")
    var environmentStoragePath: String?

}

/// Exact Swift selection shared by assessment and build commands.
struct CLIExactEnvironmentOptions: ParsableArguments, Sendable {

    @Option(name: .customLong("swift-version"), help: "Exact Swift release, such as 6.0 or 6.0.0.")
    var swiftVersion: CLISwiftVersionArgument?

    @Option(name: .customLong("architecture"), help: "Linux architecture: x86_64 or aarch64.")
    var architecture: CLIArchitecture?

    @Option(name: .customLong("environment-storage-path"), help: "Custom Swiftly environment storage directory.")
    var environmentStoragePath: String?

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

}

/// SwiftPM scratch and shared-storage controls for staged package operations.
struct CLIScratchOptions: ParsableArguments, Sendable {

    @Option(name: .customLong("scratch-path"), help: "Custom SwiftPM scratch directory.")
    var scratchPath: String?

}

/// A strict command-line spelling for an exact Swift release.
struct CLISwiftVersionArgument: ExpressibleByArgument, Sendable {

    let value: SwiftVersion

    /// Parses a canonical Swift release or its patch-zero short form.
    init?(argument: String) {

        guard let value = SwiftVersion(argument) else { return nil }
        let canonical = value.description
        let shortPatchZero = value.patch == 0 ? "\(value.major).\(value.minor)" : nil
        guard argument == canonical || argument == shortPatchZero else { return nil }
        self.value = value
    }

}

/// The two Linux architectures exposed by SwiftlyKitCLI.
enum CLIArchitecture: String, ExpressibleByArgument, Sendable {

    case x86_64
    case aarch64

    /// Maps the command spelling to SwiftlyKit's Linux architecture.
    var value: LinuxArchitecture {
        switch self {
            case .x86_64: .x86_64
            case .aarch64: .arm64
        }
    }

}

/// The SwiftPM build configuration exposed by SwiftlyKitCLI.
enum CLIConfiguration: String, ExpressibleByArgument, Sendable {

    case release
    case debug

    /// Maps the command spelling to SwiftlyKit's build configuration.
    var value: BuildConfiguration {
        switch self {
            case .release: .release
            case .debug: .debug
        }
    }

}

/// The post-publication cleanup policy for a build output.
enum CLICleanup: String, ExpressibleByArgument, Sendable {

    case retain
    case clean
    case reset

    /// Maps the command spelling to SwiftlyKit's cleanup policy.
    var value: BuildCleanup {
        switch self {
            case .retain: .retain
            case .clean: .clean
            case .reset: .reset
        }
    }

}
