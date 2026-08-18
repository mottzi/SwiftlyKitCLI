import ArgumentParser

/// Resolves package dependencies in selected SwiftPM scratch storage.
struct ResolveCommand: SwiftlyKitCLICommand {

    @Argument(help: "Package root containing Package.swift.")
    var packagePath: String?

    @OptionGroup var selection: CLIExactEnvironmentOptions
    @OptionGroup var preparation: CLIPreparationOptions
    @OptionGroup var scratch: CLIScratchOptions
    @OptionGroup var output: CLIVerboseOutputOptions

    var cliOutput: CLIOutputMode { output.cliOutput }

    func execute(in context: CLICommandContext) async throws -> CLIResult {

        let packageRoot = try context.packageRoot(packagePath)
        return try await withPreparedEnvironment(
            packageRoot: packageRoot,
            selection: selection,
            preparation: preparation,
            context: context
        ) { swiftlyKit, environment in
            try await swiftlyKit.resolveDependencies(
                in: scratch.storage(in: context),
                using: environment,
                onEvent: context.onEvent
            )
            return .resolved
        }
    }

    static let configuration = CommandConfiguration(
        commandName: "resolve",
        abstract: "Resolve package dependencies."
    )

}
