import ArgumentParser
import SwiftlyKit

/// Builds one verified static Linux executable.
struct BuildCommand: SwiftlyKitCLICommand {

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

    @Option(
        name: .customLong("output-path"),
        help: "Publish the executable and resource bundles to this directory."
    )
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

    var cliOutput: CLIOutputMode { output.cliOutput }

    mutating func validate() throws {

        if let jobs, jobs <= 0 {
            throw ValidationError("--jobs must be greater than zero.")
        }
        guard !replaceOutput || outputPath != nil else {
            throw ValidationError("--replace-output requires --output-path.")
        }
        guard outputPath != nil || cleanup == nil else {
            throw ValidationError("--cleanup requires --output-path.")
        }
    }

    func execute(in context: CLICommandContext) async throws -> CLIResult {

        let packageRoot = try context.packageRoot(packagePath)
        return try await withPreparedEnvironment(
            packageRoot: packageRoot,
            selection: selection,
            preparation: preparation,
            context: context
        ) { swiftlyKit, environment in
            let products = try await swiftlyKit.executableProducts(using: environment)
            let selectedProduct = try products.select(product)
            let buildRequest = BuildRequest(
                selectedProduct,
                configuration: configuration?.value ?? .release,
                jobs: jobs,
                scratchStorage: scratch.storage(in: context),
                output: buildOutput(in: context),
                strip: strip
            )

            let result: BuildResult
            do {
                result = try await swiftlyKit.build(
                    buildRequest,
                    using: environment,
                    onEvent: context.onEvent
                )
            } catch SwiftlyKitError.dependencyResolutionRequired {
                guard resolveDependencies else { throw SwiftlyKitError.dependencyResolutionRequired }
                try await swiftlyKit.resolveDependencies(
                    in: scratch.storage(in: context),
                    using: environment,
                    onEvent: context.onEvent
                )
                result = try await swiftlyKit.build(
                    buildRequest,
                    using: environment,
                    onEvent: context.onEvent
                )
            }

            return .built(
                CLIBuildSummary(
                    executable: result.executable,
                    directory: result.directory,
                    resourceBundles: result.resourceBundles,
                    target: selection.target,
                    configuration: configuration?.value ?? .release,
                    swiftVersion: environment.swiftVersion,
                    staticLinuxSDKIdentifier: environment.staticLinuxSDK.identifier,
                    staticLinuxSDKVersion: environment.staticLinuxSDK.version
                )
            )
        }
    }

    private func buildOutput(in context: CLICommandContext) -> BuildOutput {

        guard let outputPath else { return .buildStorage }
        return .publish(
            to: context.canonicalURL(outputPath),
            replacingExisting: replaceOutput,
            cleanup: cleanup?.value ?? .retain
        )
    }

    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build one verified static Linux executable."
    )

}
