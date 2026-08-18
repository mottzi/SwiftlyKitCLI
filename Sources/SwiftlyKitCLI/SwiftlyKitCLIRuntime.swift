import ArgumentParser
import Foundation
import SwiftlyKit

/// Argument parsing, SwiftlyKit access, and process-channel orchestration for one invocation.
public struct SwiftlyKitCLIRuntime: Sendable {

    private let version: String
    private let environment: [String: String]
    private let currentDirectory: URL
    private let workflowClient: SwiftlyKitCLIWorkflowClient
    private let renderer: CLIRenderer

    /// Creates a runtime with the live SwiftlyKit adapter.
    public init(
        version: String = "0.1.0",
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectory: URL = URL(filePath: FileManager.default.currentDirectoryPath)
    ) {

        self.version = version
        self.environment = environment
        self.currentDirectory = currentDirectory
        self.workflowClient = SwiftlyKitCLIWorkflowClient { request, onEvent in
            try await SwiftlyKitWorkflow().execute(request, onEvent: onEvent)
        }
        self.renderer = CLIRenderer(encode: { envelope in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(envelope)
        })
    }

    init(
        version: String,
        environment: [String: String],
        currentDirectory: URL,
        workflowClient: SwiftlyKitCLIWorkflowClient
    ) {

        self.version = version
        self.environment = environment
        self.currentDirectory = currentDirectory
        self.workflowClient = workflowClient
        self.renderer = CLIRenderer(encode: { envelope in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(envelope)
        })
    }

    /// Executes one argument vector and returns its stable process status.
    public func run(arguments: [String], output: any CLIOutputWriting) async -> Int32 {

        if arguments == ["--help"] || arguments == ["-h"] {
            output.writeStandardOutput(Self.rootHelp)
            return 0
        }
        if arguments == ["--version"] {
            output.writeStandardOutput("SwiftlyKitCLI \(version)\n")
            return 0
        }
        if arguments.isEmpty {
            output.writeStandardError(Self.rootHelp)
            return 2
        }
        if let help = helpText(for: arguments) {
            output.writeStandardOutput(help)
            return 0
        }

        do {
            let command = try SwiftlyKitCommand.parseAsRoot(arguments)
            guard let commandName = commandName(for: command) else {
                return renderer.renderUsage(
                    detail: "A supported subcommand is required.",
                    command: "swiftlykit",
                    json: arguments.contains("--json"),
                    output: output
                )
            }
            let request = try request(for: command, commandName: commandName)
            return await run(request, command: commandName, output: output)
        } catch {
            if let error = error as? SwiftlyKitError,
               case .invalidPackageRoot = error {
                return renderer.render(
                    error: error,
                    command: commandName(from: arguments),
                    json: arguments.contains("--json"),
                    output: output
                )
            }
            return renderer.renderUsage(
                detail: error.localizedDescription,
                command: commandName(from: arguments),
                json: arguments.contains("--json"),
                output: output
            )
        }
    }

}

extension SwiftlyKitCLIRuntime {

    private func run(_ request: CLIRequest, command: String, output: any CLIOutputWriting) async -> Int32 {

        let json = request.json
        let verbose = request.verbose
        let cancellation = CLICancellationCoordinator(
            json: json,
            output: output,
            forceExit: { status in _exit(status) }
        )
        let invocation = Task<Int32, Never> {
            do {
                let eventHandler: SwiftlyKitEvent.Handler? = { [renderer] event in
                    renderer.render(event: event, verbose: verbose, json: json, output: output)
                }
                let result = try await workflowClient.execute(request, onEvent: eventHandler)
                try Task.checkCancellation()
                return renderer.render(result: result, command: command, json: json, output: output)
            } catch is CancellationError {
                return renderer.renderCancellation(command: command, json: json, output: output)
            } catch {
                return renderer.render(error: error, command: command, json: json, output: output)
            }
        }
        await cancellation.attach(invocationTask: invocation)

        let signals = CLISignalSources { Task { await cancellation.receiveSignal() } }
        signals.activate()
        defer { signals.cancel() }
        return await invocation.value
    }

    private func request(for command: Any, commandName: String) throws -> CLIRequest {

        switch command {
            case let command as HostReadinessCommand:
                return CLIRequest(
                    operation: .hostReadiness,
                    verbose: false,
                    json: command.output.json
                )
            case let command as InstallCommandLineToolsCommand:
                return CLIRequest(
                    operation: .installCommandLineTools,
                    verbose: false,
                    json: command.output.json
                )
            case let command as EnvironmentsCommand:
                let root = try packageRoot(command.packagePath)
                return CLIRequest(
                    operation: .environments,
                    packageRoot: root,
                    target: .linux((command.selection.architecture ?? .x86_64).value),
                    environmentStorage: try environmentStorage(command.selection.environmentStoragePath),
                    verbose: false,
                    json: command.output.json
                )
            case let command as AssessCommand:
                let root = try packageRoot(command.packagePath)
                return CLIRequest(
                    operation: .assess,
                    packageRoot: root,
                    target: .linux((command.selection.architecture ?? .x86_64).value),
                    toolchain: command.selection.swiftVersion.map { .exact($0.value) } ?? .automatic,
                    environmentStorage: try environmentStorage(command.selection.environmentStoragePath),
                    verbose: false,
                    json: command.output.json
                )
            case let command as PrepareCommand:
                let root = try packageRoot(command.packagePath)
                return try stagedRequest(
                    operation: .prepare,
                    packageRoot: root,
                    selection: command.selection,
                    preparation: command.preparation,
                    scratch: nil,
                    output: command.output
                )
            case let command as ProductsCommand:
                let root = try packageRoot(command.packagePath)
                return try stagedRequest(
                    operation: .products,
                    packageRoot: root,
                    selection: command.selection,
                    preparation: command.preparation,
                    scratch: nil,
                    output: command.output
                )
            case let command as ResolveCommand:
                let root = try packageRoot(command.packagePath)
                return try stagedRequest(
                    operation: .resolve,
                    packageRoot: root,
                    selection: command.selection,
                    preparation: command.preparation,
                    scratch: command.scratch,
                    output: command.output
                )
            case let command as BuildCommand:
                let root = try packageRoot(command.packagePath)
                return try buildRequest(command, packageRoot: root)
            case let command as CleanCommand:
                let root = try packageRoot(command.packagePath)
                return try stagedRequest(
                    operation: .clean,
                    packageRoot: root,
                    selection: command.selection,
                    preparation: command.preparation,
                    scratch: command.scratch,
                    output: command.output
                )
            case let command as ResetCommand:
                let root = try packageRoot(command.packagePath)
                return try stagedRequest(
                    operation: .reset,
                    packageRoot: root,
                    selection: command.selection,
                    preparation: command.preparation,
                    scratch: command.scratch,
                    output: command.output
                )
            case let command as RemoveCommand:
                return try removalRequest(command)
            default:
                throw CLIRequestError.unsupportedCommand(commandName)
        }
    }

    private func stagedRequest(
        operation: CLIRequestOperation,
        packageRoot: URL,
        selection: CLIExactEnvironmentOptions,
        preparation: CLIPreparationOptions,
        scratch: CLIScratchOptions?,
        output: CLIVerboseOutputOptions
    ) throws -> CLIRequest {

        try validate(
            preparation: preparation,
            jobs: nil,
            verbose: output.verbose,
            json: output.json
        )
        return CLIRequest(
            operation: operation,
            packageRoot: packageRoot,
            target: .linux((selection.architecture ?? .x86_64).value),
            toolchain: selection.swiftVersion.map { .exact($0.value) } ?? .automatic,
            configuration: .release,
            scratchStorage: try scratchStorage(scratch?.scratchPath),
            output: .buildStorage,
            installEnvironment: preparation.installEnvironment,
            swiftPMEnvironment: try swiftPMEnvironment(preparation),
            swiftPMTraits: try swiftPMTraits(preparation),
            swiftPMSharedStorage: try sharedStorage(preparation),
            environmentStorage: try environmentStorage(selection.environmentStoragePath),
            removalPlanPath: preparation.removalPlanPath.map(canonicalURL),
            verbose: output.verbose,
            json: output.json
        )
    }

    private func buildRequest(_ command: BuildCommand, packageRoot: URL) throws -> CLIRequest {

        try validate(
            preparation: command.preparation,
            jobs: command.jobs,
            verbose: command.output.verbose,
            json: command.output.json
        )
        guard !command.replaceOutput || command.outputPath != nil else {
            throw CLIRequestError.outputOptionRequiresPath
        }
        let output: BuildOutput
        if let path = command.outputPath {
            output = .publish(
                to: canonicalURL(path),
                replacingExisting: command.replaceOutput,
                cleanup: command.cleanup?.value ?? .retain
            )
        } else {
            guard command.cleanup == nil else { throw CLIRequestError.outputOptionRequiresPath }
            output = .buildStorage
        }
        return CLIRequest(
            operation: .build,
            packageRoot: packageRoot,
            target: .linux((command.selection.architecture ?? .x86_64).value),
            toolchain: command.selection.swiftVersion.map { .exact($0.value) } ?? .automatic,
            configuration: command.configuration?.value ?? .release,
            product: command.product,
            jobs: command.jobs,
            scratchStorage: try scratchStorage(command.scratch.scratchPath),
            output: output,
            strip: command.strip,
            resolveDependencies: command.resolveDependencies,
            installEnvironment: command.preparation.installEnvironment,
            swiftPMEnvironment: try swiftPMEnvironment(command.preparation),
            swiftPMTraits: try swiftPMTraits(command.preparation),
            swiftPMSharedStorage: try sharedStorage(command.preparation),
            environmentStorage: try environmentStorage(command.selection.environmentStoragePath),
            removalPlanPath: command.preparation.removalPlanPath.map(canonicalURL),
            verbose: command.output.verbose,
            json: command.output.json
        )
    }

    private func removalRequest(_ command: RemoveCommand) throws -> CLIRequest {

        guard !(command.output.verbose && command.output.json) else {
            throw CLIRequestError.verboseJSONConflict
        }
        guard command.removalPlanPath != nil || command.swiftVersion != nil || command.sdkIdentifier != nil else {
            throw CLIRequestError.emptyRemovalSpecification
        }
        guard command.removalPlanPath == nil || (command.swiftVersion == nil && command.sdkIdentifier == nil
            && command.environmentStoragePath == nil) else {
            throw CLIRequestError.mixedRemovalSpecification
        }

        let plan: EnvironmentRemovalPlan
        if let path = command.removalPlanPath {
            do { plan = try JSONDecoder().decode(EnvironmentRemovalPlan.self, from: Data(contentsOf: canonicalURL(path))) }
            catch { throw CLIRequestError.invalidRemovalPlan(canonicalURL(path)) }
        } else {
            let storage = try environmentStorage(command.environmentStoragePath)
            switch (command.swiftVersion?.value, command.sdkIdentifier) {
                case let (.some(version), .some(identifier)):
                    plan = try EnvironmentRemovalPlan.environment(
                        toolchain: version,
                        staticLinuxSDKIdentifier: identifier,
                        in: storage
                    )
                case let (.some(version), nil):
                    plan = .toolchain(version, in: storage)
                case let (nil, .some(identifier)):
                    plan = try EnvironmentRemovalPlan.staticLinuxSDK(identifier: identifier, in: storage)
                case (nil, nil):
                    throw CLIRequestError.emptyRemovalSpecification
            }
        }

        return CLIRequest(
            operation: .remove,
            removalPlan: plan,
            verbose: command.output.verbose,
            json: command.output.json
        )
    }

}

extension SwiftlyKitCLIRuntime {

    private func packageRoot(_ path: String?) throws -> URL {

        let root = path.map(canonicalURL) ?? canonicalURL(currentDirectory.path(percentEncoded: false))
        let manifest = root.appending(path: "Package.swift")
        var rootIsDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path(percentEncoded: false), isDirectory: &rootIsDirectory),
              rootIsDirectory.boolValue else {
            throw SwiftlyKitError.invalidPackageRoot(root)
        }

        var manifestIsDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: manifest.path(percentEncoded: false),
            isDirectory: &manifestIsDirectory
        ),
              !manifestIsDirectory.boolValue,
              FileManager.default.isReadableFile(atPath: manifest.path(percentEncoded: false)) else {
            throw SwiftlyKitError.invalidPackageRoot(root)
        }
        return root
    }

    private func environmentStorage(_ path: String?) throws -> EnvironmentStorage {
        guard let path else { return .standard }
        return .directory(canonicalURL(path))
    }

    private func validate(preparation: CLIPreparationOptions, jobs: Int?, verbose: Bool, json: Bool) throws {

        guard !(verbose && json) else { throw CLIRequestError.verboseJSONConflict }
        guard jobs.map({ $0 > 0 }) ?? true else { throw SwiftlyKitError.invalidBuildJobCount(jobs!) }
        guard !(preparation.noTraits && preparation.allTraits) else { throw CLIRequestError.traitConflict }
        guard !(preparation.noTraits && !preparation.traits.isEmpty) else { throw CLIRequestError.traitConflict }
        guard !(preparation.allTraits && !preparation.traits.isEmpty) else { throw CLIRequestError.traitConflict }
        guard !preparation.includeDefaultTraits || !preparation.traits.isEmpty else {
            throw CLIRequestError.includeDefaultsRequiresTraits
        }
    }

    private func scratchStorage(_ path: String?) throws -> SwiftPMScratchStorage {
        guard let path else { return .packageDefault }
        return .directory(canonicalURL(path))
    }

    private func swiftPMEnvironment(_ options: CLIPreparationOptions) throws -> SwiftPMEnvironment {

        let allNames = options.environmentNames + options.sensitiveEnvironmentNames + options.unsetEnvironmentNames
        var seen = Set<String>()
        for name in allNames {
            guard seen.insert(name).inserted else { throw CLIRequestError.duplicateEnvironment(name) }
        }

        var values: [String: SwiftPMEnvironment.Value] = [:]
        for name in options.environmentNames {
            guard let value = environment[name] else { throw CLIRequestError.missingEnvironmentValue(name) }
            values[name] = .plain(value)
        }
        for name in options.sensitiveEnvironmentNames {
            guard let value = environment[name] else { throw CLIRequestError.missingEnvironmentValue(name) }
            values[name] = .sensitive(value)
        }
        for name in options.unsetEnvironmentNames { values[name] = .unset }
        return try SwiftPMEnvironment(values)
    }

    private func swiftPMTraits(_ options: CLIPreparationOptions) throws -> SwiftPMTraits {

        if options.noTraits { return .none }
        if options.allTraits { return .all }
        guard !options.traits.isEmpty else { return .packageDefaults }
        return try SwiftPMTraits(options.traits, includingDefaults: options.includeDefaultTraits)
    }

    private func sharedStorage(_ options: CLIPreparationOptions) throws -> SwiftPMSharedStorage {
        SwiftPMSharedStorage(
            cacheDirectory: options.cachePath.map(canonicalURL),
            configurationDirectory: options.swiftPMConfigurationPath.map(canonicalURL),
            securityDirectory: options.securityPath.map(canonicalURL)
        )
    }

    private func canonicalURL(_ path: String) -> URL {
        let url = path.hasPrefix("/") ? URL(filePath: path) : currentDirectory.appending(path: path)
        return url.resolvingSymlinksInPath().standardizedFileURL
    }

}

extension SwiftlyKitCLIRuntime {

    private func helpText(for arguments: [String]) -> String? {

        guard arguments.count == 2,
              (arguments[0] == "help" || arguments[1] == "--help" || arguments[1] == "-h")
        else { return nil }
        let name = arguments[0] == "help" ? arguments[1] : arguments[0]
        let command: ParsableCommand.Type
        switch name {
            case "host-readiness": command = HostReadinessCommand.self
            case "install-command-line-tools": command = InstallCommandLineToolsCommand.self
            case "environments": command = EnvironmentsCommand.self
            case "assess": command = AssessCommand.self
            case "prepare": command = PrepareCommand.self
            case "products": command = ProductsCommand.self
            case "resolve": command = ResolveCommand.self
            case "build": command = BuildCommand.self
            case "clean": command = CleanCommand.self
            case "reset": command = ResetCommand.self
            case "remove": command = RemoveCommand.self
            default: return nil
        }
        return SwiftlyKitCommand.helpMessage(for: command, columns: 100)
    }

    private func commandName(for command: Any) -> String? {

        switch command {
            case is HostReadinessCommand: "host-readiness"
            case is InstallCommandLineToolsCommand: "install-command-line-tools"
            case is EnvironmentsCommand: "environments"
            case is AssessCommand: "assess"
            case is PrepareCommand: "prepare"
            case is ProductsCommand: "products"
            case is ResolveCommand: "resolve"
            case is BuildCommand: "build"
            case is CleanCommand: "clean"
            case is ResetCommand: "reset"
            case is RemoveCommand: "remove"
            default: nil
        }
    }

    private func commandName(from arguments: [String]) -> String {
        arguments.first(where: { !$0.hasPrefix("-") }) ?? "swiftlykit"
    }

}

extension SwiftlyKitCLIRuntime {

    private static let rootHelp = """
        OVERVIEW: Prepare Swift environments and build verified static Linux executables.

        USAGE: swiftlykit <subcommand>

        OPTIONS:
          --version               Show the version.
          -h, --help              Show help information.

        SUBCOMMANDS:
          host-readiness           Check host developer-tool readiness.
          install-command-line-tools
                                  Request Apple's Command Line Tools installer.
          environments             List compatible Swift environments.
          assess                   Assess the selected Swift environment.
          prepare                  Prepare the selected Swift environment.
          products                 List executable package products.
          resolve                  Resolve package dependencies.
          build                    Build one verified static Linux executable.
          clean                    Clean compiled build artifacts.
          reset                    Reset SwiftPM scratch storage.
          remove                   Remove exact Swiftly-managed resources.

        """

}

/// One controlled workflow client used by the CLI runtime and its tests.
struct SwiftlyKitCLIWorkflowClient: Sendable {

    /// The single internal CLI-to-library seam.
    typealias Handler = @Sendable (CLIRequest, SwiftlyKitEvent.Handler?) async throws -> CLIResult

    private let handler: Handler

    /// Creates a client from one modeled request handler.
    init(handler: @escaping Handler) {
        self.handler = handler
    }

    /// Executes one request and observes its SwiftlyKit events.
    func execute(_ request: CLIRequest, onEvent: SwiftlyKitEvent.Handler?) async throws -> CLIResult {
        try await handler(request, onEvent)
    }

}

/// CLI-only request validation failures.
enum CLIRequestError: Error, LocalizedError, Sendable {

    case unsupportedCommand(String)
    case verboseJSONConflict
    case traitConflict
    case includeDefaultsRequiresTraits
    case duplicateEnvironment(String)
    case missingEnvironmentValue(String)
    case outputOptionRequiresPath
    case emptyRemovalSpecification
    case mixedRemovalSpecification
    case invalidRemovalPlan(URL)

    /// Returns a stable user-facing request diagnostic.
    var errorDescription: String? {
        switch self {
            case .unsupportedCommand(let command):
                "Unsupported command: \(command)."

            case .verboseJSONConflict:
                "--verbose and --json are mutually exclusive."

            case .traitConflict:
                "The trait flags are mutually exclusive."

            case .includeDefaultsRequiresTraits:
                "--include-default-traits requires at least one --trait."

            case .duplicateEnvironment(let name):
                "The environment variable ‘\(name)’ was requested more than once."

            case .missingEnvironmentValue(let name):
                "The environment variable ‘\(name)’ is not present in this process."

            case .outputOptionRequiresPath:
                "--replace-output and --cleanup require --output-path."

            case .emptyRemovalSpecification:
                "Provide a removal-plan path, --swift-version, or --sdk-identifier."

            case .mixedRemovalSpecification:
                "A removal-plan path cannot be combined with manual removal options."

            case .invalidRemovalPlan(let url):
                "The removal plan is invalid: \(url.path(percentEncoded: false))."

        }
    }

}
