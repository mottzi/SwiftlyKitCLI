import ArgumentParser

/// Prepares one selected Swift environment.
struct PrepareCommand: SwiftlyKitCLICommand {

    @Argument(help: "Package root containing Package.swift.")
    var packagePath: String?

    @OptionGroup var selection: CLIExactEnvironmentOptions
    @OptionGroup var preparation: CLIPreparationOptions
    @OptionGroup var output: CLIVerboseOutputOptions

    var cliOutput: CLIOutputMode { output.cliOutput }

    func execute(in context: CLICommandContext) async throws -> CLIResult {

        let packageRoot = try context.packageRoot(packagePath)
        return try await withPreparedEnvironment(
            packageRoot: packageRoot,
            selection: selection,
            preparation: preparation,
            context: context
        ) { _, environment in
            .prepared(CLIPreparedSummary(environment))
        }
    }

    static let configuration = CommandConfiguration(
        commandName: "prepare",
        abstract: "Prepare the selected Swift environment."
    )

}
