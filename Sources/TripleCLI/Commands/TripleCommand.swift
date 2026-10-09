import ArgumentParser

/// Root command tree for the standalone Triple command-line tool.
struct TripleCommand: AsyncParsableCommand {

    @Flag(name: .customLong("version"), help: "Show the version.")
    var showVersion = false

    mutating func validate() throws {
        guard !showVersion else {
            throw ValidationError("--version is only valid at the root.")
        }
    }

    static let configuration = CommandConfiguration(
        commandName: "triple",
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
