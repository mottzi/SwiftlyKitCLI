import ArgumentParser

/// Lists executable products from one prepared package.
struct ProductsCommand: SwiftlyKitCLICommand {

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
        ) { swiftlyKit, environment in
            let products = try await swiftlyKit.executableProducts(using: environment)
            return .products(products.map(\.name))
        }
    }

    static let configuration = CommandConfiguration(
        commandName: "products",
        abstract: "List executable package products."
    )

}
