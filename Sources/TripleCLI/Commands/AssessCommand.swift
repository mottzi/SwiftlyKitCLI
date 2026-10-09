import ArgumentParser
import Triple

/// Assesses one exact environment without changing state.
struct AssessCommand: TripleCLICommand {

    @Argument(help: "Package root containing Package.swift.")
    var packagePath: String?

    @OptionGroup var selection: CLIExactEnvironmentOptions
    @OptionGroup var output: CLIOutputOptions

    func execute(in context: CLICommandContext) async throws -> CLIResult {

        let packageRoot = try context.packageRoot(packagePath)
        let triple = Triple(
            environmentStorage: try selection.environmentStorage(in: context)
        )
        let assessment = try await triple.assess(
            packageRoot,
            for: selection.target,
            toolchain: selection.toolchain
        )
        return .assessment(CLIEnvironmentSummary(assessment))
    }

    var cliOutput: CLIOutputMode { CLIOutputMode(json: output.json) }

    static let configuration = CommandConfiguration(
        commandName: "assess",
        abstract: "Assess the selected Swift environment."
    )

}
