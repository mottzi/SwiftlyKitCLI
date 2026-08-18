import Foundation
import SwiftlyKit

/// One operation admitted by the command-line interface.
enum CLIRequestOperation: Sendable {

    case hostReadiness
    case installCommandLineTools
    case environments
    case assess
    case prepare
    case products
    case resolve
    case build
    case clean
    case reset
    case remove

}

/// One fully validated command request passed through the CLI's single workflow seam.
struct CLIRequest: Sendable {

    let operation: CLIRequestOperation
    let packageRoot: URL?
    let target: BuildTarget
    let toolchain: ToolchainSelection
    let configuration: BuildConfiguration
    let product: String?
    let jobs: Int?
    let scratchStorage: SwiftPMScratchStorage
    let output: BuildOutput
    let strip: Bool
    let resolveDependencies: Bool
    let installEnvironment: Bool
    let swiftPMEnvironment: SwiftPMEnvironment
    let swiftPMTraits: SwiftPMTraits
    let swiftPMSharedStorage: SwiftPMSharedStorage
    let environmentStorage: EnvironmentStorage
    let removalPlanPath: URL?
    let removalPlan: EnvironmentRemovalPlan?
    let verbose: Bool
    let json: Bool

    init(
        operation: CLIRequestOperation,
        packageRoot: URL? = nil,
        target: BuildTarget = .linux(.x86_64),
        toolchain: ToolchainSelection = .automatic,
        configuration: BuildConfiguration = .release,
        product: String? = nil,
        jobs: Int? = nil,
        scratchStorage: SwiftPMScratchStorage = .packageDefault,
        output: BuildOutput = .buildStorage,
        strip: Bool = false,
        resolveDependencies: Bool = false,
        installEnvironment: Bool = false,
        swiftPMEnvironment: SwiftPMEnvironment = .inherited,
        swiftPMTraits: SwiftPMTraits = .packageDefaults,
        swiftPMSharedStorage: SwiftPMSharedStorage = .standard,
        environmentStorage: EnvironmentStorage = .standard,
        removalPlanPath: URL? = nil,
        removalPlan: EnvironmentRemovalPlan? = nil,
        verbose: Bool = false,
        json: Bool = false
    ) {

        self.operation = operation
        self.packageRoot = packageRoot
        self.target = target
        self.toolchain = toolchain
        self.configuration = configuration
        self.product = product
        self.jobs = jobs
        self.scratchStorage = scratchStorage
        self.output = output
        self.strip = strip
        self.resolveDependencies = resolveDependencies
        self.installEnvironment = installEnvironment
        self.swiftPMEnvironment = swiftPMEnvironment
        self.swiftPMTraits = swiftPMTraits
        self.swiftPMSharedStorage = swiftPMSharedStorage
        self.environmentStorage = environmentStorage
        self.removalPlanPath = removalPlanPath
        self.removalPlan = removalPlan
        self.verbose = verbose
        self.json = json
    }

}

/// A compact environment assessment exposed by the CLI workflow.
struct CLIEnvironmentSummary: Sendable {

    let packageRoot: URL
    let toolsVersion: SwiftVersion
    let swiftVersion: SwiftVersion
    let staticLinuxSDKIdentifier: String
    let staticLinuxSDKVersion: String
    let requiredComponents: [PreparationComponent]
    let isSwiftlyAvailable: Bool
    let isToolchainAvailable: Bool
    let isStaticLinuxSDKAvailable: Bool
    let requiresInstallation: Bool

    init(
        packageRoot: URL,
        toolsVersion: SwiftVersion,
        swiftVersion: SwiftVersion,
        staticLinuxSDKIdentifier: String,
        staticLinuxSDKVersion: String,
        requiredComponents: [PreparationComponent],
        isSwiftlyAvailable: Bool,
        isToolchainAvailable: Bool,
        isStaticLinuxSDKAvailable: Bool,
        requiresInstallation: Bool
    ) {

        self.packageRoot = packageRoot
        self.toolsVersion = toolsVersion
        self.swiftVersion = swiftVersion
        self.staticLinuxSDKIdentifier = staticLinuxSDKIdentifier
        self.staticLinuxSDKVersion = staticLinuxSDKVersion
        self.requiredComponents = requiredComponents
        self.isSwiftlyAvailable = isSwiftlyAvailable
        self.isToolchainAvailable = isToolchainAvailable
        self.isStaticLinuxSDKAvailable = isStaticLinuxSDKAvailable
        self.requiresInstallation = requiresInstallation
    }

    /// Builds a CLI summary from one SwiftlyKit environment assessment.
    init(_ assessment: EnvironmentAssessment) {

        packageRoot = assessment.packageRoot
        toolsVersion = assessment.toolsVersion
        swiftVersion = assessment.swiftVersion
        staticLinuxSDKIdentifier = assessment.staticLinuxSDK.identifier
        staticLinuxSDKVersion = assessment.staticLinuxSDK.version
        requiredComponents = assessment.requiredComponents
        isSwiftlyAvailable = assessment.isSwiftlyAvailable
        isToolchainAvailable = assessment.isToolchainAvailable
        isStaticLinuxSDKAvailable = assessment.isStaticLinuxSDKAvailable
        requiresInstallation = assessment.requiresInstallation
    }

}

/// A compact prepared-environment result exposed by the CLI workflow.
struct CLIPreparedSummary: Sendable {

    let swiftVersion: SwiftVersion
    let staticLinuxSDKIdentifier: String
    let staticLinuxSDKVersion: String

    /// Builds a CLI summary from one prepared SwiftlyKit environment.
    init(_ environment: LocalBuildEnvironment) {
        swiftVersion = environment.swiftVersion
        staticLinuxSDKIdentifier = environment.staticLinuxSDK.identifier
        staticLinuxSDKVersion = environment.staticLinuxSDK.version
    }

}

/// A compact verified build result exposed by the CLI workflow.
struct CLIBuildSummary: Sendable {

    let executable: URL
    let directory: URL
    let resourceBundles: [URL]
    let target: BuildTarget
    let configuration: BuildConfiguration
    let swiftVersion: SwiftVersion
    let staticLinuxSDKIdentifier: String
    let staticLinuxSDKVersion: String
    let verification: String

}

/// A modeled success or required-action outcome from one SwiftlyKit operation.
enum CLIResult: Sendable {

    case hostReadiness(HostReadiness)
    case commandLineToolsInstallation
    case environments([CLIEnvironmentSummary])
    case assessment(CLIEnvironmentSummary)
    case preparationRequired(CLIEnvironmentSummary)
    case prepared(CLIPreparedSummary)
    case products([String])
    case resolved
    case built(CLIBuildSummary)
    case cleaned
    case reset
    case removed

}

/// Errors raised while writing an explicit removal-plan record.
enum CLIWorkflowError: Error, LocalizedError, Sendable {

    case removalPlanParentMissing(URL)
    case removalPlanWriteFailed(URL)
    case missingPackageRoot
    case missingRemovalPlan

    /// Returns a concise diagnostic for the failed workflow operation.
    var errorDescription: String? {
        switch self {
            case .removalPlanParentMissing(let url):
                "The removal-plan parent directory does not exist: \(url.path(percentEncoded: false))."

            case .removalPlanWriteFailed(let url):
                "The removal plan could not be written: \(url.path(percentEncoded: false))."

            case .missingPackageRoot:
                "The command requires a package root."

            case .missingRemovalPlan:
                "The remove command requires a removal plan or an exact manual specification."
        }
    }

}

/// The live adapter that translates one modeled request into pure SwiftlyKit calls.
struct SwiftlyKitWorkflow: Sendable {

    /// Executes one validated request and returns one modeled terminal result.
    func execute(_ request: CLIRequest, onEvent: SwiftlyKitEvent.Handler?) async throws -> CLIResult {

        switch request.operation {
            case .hostReadiness:
                return .hostReadiness(try await SwiftlyKit.hostReadiness())

            case .installCommandLineTools:
                try await SwiftlyKit.requestCommandLineToolsInstallation()
                return .commandLineToolsInstallation

            case .remove:
                guard let plan = request.removalPlan else { throw CLIWorkflowError.missingRemovalPlan }
                try await SwiftlyKit.remove(plan, onEvent: onEvent)
                return .removed

            case .environments:
                let packageRoot = try requirePackageRoot(request)
                let choices = try await SwiftlyKit(environmentStorage: request.environmentStorage)
                    .compatibleEnvironments(packageRoot, for: request.target)
                return .environments(choices.map(CLIEnvironmentSummary.init))

            case .assess:
                let assessment = try await assess(request)
                return .assessment(CLIEnvironmentSummary(assessment))

            case .prepare, .products, .resolve, .build, .clean, .reset:
                return try await executePrepared(request, onEvent: onEvent)
        }
    }

}

extension SwiftlyKitWorkflow {

    private func executePrepared(_ request: CLIRequest, onEvent: SwiftlyKitEvent.Handler?) async throws -> CLIResult {

        let assessment = try await assess(request)
        let summary = CLIEnvironmentSummary(assessment)
        guard !assessment.requiresInstallation || request.installEnvironment else {
            return .preparationRequired(summary)
        }

        let recordRemovalPlan: EnvironmentRemovalPlan.Recorder?
        if let path = request.removalPlanPath {
            recordRemovalPlan = try removalPlanRecorder(at: path)
        } else {
            recordRemovalPlan = nil
        }

        let swiftlyKit = SwiftlyKit(environmentStorage: request.environmentStorage)
        let environment = try await swiftlyKit.prepare(
            assessment,
            swiftPMEnvironment: request.swiftPMEnvironment,
            swiftPMTraits: request.swiftPMTraits,
            swiftPMSharedStorage: request.swiftPMSharedStorage,
            recordRemovalPlan: recordRemovalPlan,
            onEvent: onEvent
        )

        switch request.operation {
            case .prepare:
                return .prepared(CLIPreparedSummary(environment))

            case .products:
                let products = try await swiftlyKit.executableProducts(using: environment)
                return .products(products.map(\.name))

            case .resolve:
                try await swiftlyKit.resolveDependencies(
                    in: request.scratchStorage,
                    using: environment,
                    onEvent: onEvent
                )
                return .resolved

            case .build:
                return try await build(request, using: swiftlyKit, environment: environment, onEvent: onEvent)

            case .clean:
                try await swiftlyKit.cleanBuildArtifacts(
                    in: request.scratchStorage,
                    using: environment,
                    onEvent: onEvent
                )
                return .cleaned

            case .reset:
                try await swiftlyKit.resetBuildStorage(
                    in: request.scratchStorage,
                    using: environment,
                    onEvent: onEvent
                )
                return .reset

            default:
                throw SwiftlyKitError.mutationCoordinationFailed("The requested prepared operation is not supported.")
        }
    }

    private func assess(_ request: CLIRequest) async throws -> EnvironmentAssessment {

        let packageRoot = try requirePackageRoot(request)
        return try await SwiftlyKit(environmentStorage: request.environmentStorage).assess(
            packageRoot,
            for: request.target,
            toolchain: request.toolchain
        )
    }

    private func requirePackageRoot(_ request: CLIRequest) throws -> URL {
        guard let packageRoot = request.packageRoot else { throw CLIWorkflowError.missingPackageRoot }
        return packageRoot
    }

    private func removalPlanRecorder(at path: URL) throws -> EnvironmentRemovalPlan.Recorder {

        let parent = path.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path(percentEncoded: false), isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw CLIWorkflowError.removalPlanParentMissing(parent)
        }

        return { plan in
            do {
                let data = try JSONEncoder().encode(plan)
                try data.write(to: path, options: .atomic)
            } catch {
                throw CLIWorkflowError.removalPlanWriteFailed(path)
            }
        }
    }

    private func build(
        _ request: CLIRequest,
        using swiftlyKit: SwiftlyKit,
        environment: LocalBuildEnvironment,
        onEvent: SwiftlyKitEvent.Handler?
    ) async throws -> CLIResult {

        let products = try await swiftlyKit.executableProducts(using: environment)
        let product = try products.select(request.product)
        let buildRequest = BuildRequest(
            product,
            configuration: request.configuration,
            jobs: request.jobs,
            scratchStorage: request.scratchStorage,
            output: request.output,
            strip: request.strip
        )

        let result: BuildResult
        do {
            result = try await swiftlyKit.build(buildRequest, using: environment, onEvent: onEvent)
        } catch SwiftlyKitError.dependencyResolutionRequired {
            guard request.resolveDependencies else { throw SwiftlyKitError.dependencyResolutionRequired }
            try await swiftlyKit.resolveDependencies(
                in: request.scratchStorage,
                using: environment,
                onEvent: onEvent
            )
            result = try await swiftlyKit.build(buildRequest, using: environment, onEvent: onEvent)
        }

        return .built(
            CLIBuildSummary(
                executable: result.executable,
                directory: result.directory,
                resourceBundles: result.resourceBundles,
                target: request.target,
                configuration: request.configuration,
                swiftVersion: environment.swiftVersion,
                staticLinuxSDKIdentifier: environment.staticLinuxSDK.identifier,
                staticLinuxSDKVersion: environment.staticLinuxSDK.version,
                verification: "verified"
            )
        )
    }

}
