import Darwin
import Foundation
import SwiftlyKit

/// Serialized stdout and stderr boundary used by the command runtime.
public protocol CLIOutputWriting: Sendable {

    /// Whether standard error is connected to an interactive terminal.
    var standardErrorIsTTY: Bool { get }

    /// Writes one complete value to standard output.
    func writeStandardOutput(_ value: String)

    /// Writes one complete value to standard error.
    func writeStandardError(_ value: String)

}

extension CLIOutputWriting {

    /// Defaults injected output to deterministic noninteractive rendering.
    public var standardErrorIsTTY: Bool { false }

}

/// Converts modeled results and failures to the CLI channel contract.
struct CLIRenderer: Sendable {

    let encode: @Sendable (CLIJSONEnvelope) throws -> Data

    /// Renders one successful or preparation-required result and returns its status.
    func render(result: CLIResult, command: String, json: Bool, output: any CLIOutputWriting) -> Int32 {

        if case .preparationRequired(let summary) = result {
            return renderPreparationRequired(summary, command: command, json: json, output: output)
        }

        let payload = successPayload(result)
        if json {
            guard writeJSON(
                CLIJSONEnvelope(command: command, outcome: "success", result: payload),
                output: output
            ) else { return 1 }
            return 0
        }

        output.writeStandardOutput(humanSuccess(result))
        return 0
    }

    /// Renders one operational failure and returns its stable status.
    func render(error: Error, command: String, json: Bool, output: any CLIOutputWriting) -> Int32 {

        let status = status(for: error)
        let code = code(for: error)
        let message = message(for: error)
        let detail = error.localizedDescription
        if json {
            let errorValue: CLIJSONValue = .object([
                "code": .string(code),
                "message": .string(message),
                "detail": .string(detail)
            ])
            guard writeJSON(
                CLIJSONEnvelope(command: command, outcome: "failure", error: errorValue),
                output: output
            ) else { return 1 }
        } else {
            output.writeStandardError("error: \(message)\ndetail: \(detail)\n\n")
        }
        return status
    }

    /// Renders a syntax or request error without opening SwiftlyKit.
    func renderUsage(detail: String, command: String, json: Bool, output: any CLIOutputWriting) -> Int32 {

        if json {
            let value: CLIJSONValue = .object([
                "code": .string("usage"),
                "message": .string("The command is invalid."),
                "detail": .string(detail)
            ])
            guard writeJSON(
                CLIJSONEnvelope(command: command, outcome: "failure", error: value),
                output: output
            ) else { return 1 }
        } else {
            output.writeStandardError("error: The command is invalid.\ndetail: \(detail)\n\n")
        }
        return 2
    }

    /// Renders cancellation as the sole terminal outcome.
    func renderCancellation(command: String, json: Bool, output: any CLIOutputWriting) -> Int32 {

        if json {
            guard writeJSON(CLIJSONEnvelope(command: command, outcome: "cancelled"), output: output)
            else { return 1 }
        } else {
            output.writeStandardError("cancelled: Operation cancelled.\n")
        }
        return 130
    }

    /// Renders one required environment installation action.
    func renderPreparationRequired(
        _ summary: CLIEnvironmentSummary,
        command: String,
        json: Bool,
        output: any CLIOutputWriting
    ) -> Int32 {

        let preparation = environmentPayload(summary)
        if json {
            guard writeJSON(
                CLIJSONEnvelope(command: command, outcome: "preparationRequired", preparation: preparation),
                output: output
            ) else { return 1 }
        } else {
            output.writeStandardError(
                "action required: the selected environment is not installed.\n"
                    + "Swift: \(summary.swiftVersion.description)\n"
                    + "Static Linux SDK: \(summary.staticLinuxSDKIdentifier)\n"
                    + "required: \(summary.requiredComponents.map(componentName).joined(separator: ", "))\n"
                    + "recovery: rerun with --install-environment.\n"
            )
        }
        return 3
    }

    /// Writes one progress, command, or raw output event to human standard error.
    func render(event: SwiftlyKitEvent, verbose: Bool, json: Bool, output: any CLIOutputWriting) {

        guard !json else { return }
        switch event {
            case .progress(let progress):
                output.writeStandardError("[swiftlykit] \(progress.detail)\n")

            case .command(let command):
                guard verbose else { return }
                let arguments = command.arguments.map(shellQuote).joined(separator: " ")
                output.writeStandardError("$ \(command.executable.path(percentEncoded: false)) \(arguments)\n")

            case .output(let chunk):
                guard verbose else { return }
                output.writeStandardError(chunk.text)
        }
    }

}

extension CLIRenderer {

    private func writeJSON(_ envelope: CLIJSONEnvelope, output: any CLIOutputWriting) -> Bool {

        do {
            let data = try encode(envelope)
            output.writeStandardOutput(String(decoding: data, as: UTF8.self) + "\n")
            return true
        } catch {
            output.writeStandardError("error: The result could not be encoded.\n")
            return false
        }
    }

    private func successPayload(_ result: CLIResult) -> CLIJSONValue {

        switch result {
            case .hostReadiness(let readiness): return .object(["readiness": .string(readinessName(readiness))])
            case .commandLineToolsInstallation: return .object(["requested": .boolean(true)])
            case .environments(let values): return .object(["environments": .array(values.map(environmentPayload))])
            case .assessment(let summary), .preparationRequired(let summary): return environmentPayload(summary)
            case .prepared(let summary): return preparedPayload(summary)
            case .products(let products): return .object(["products": .array(products.map { .string($0) })])
            case .resolved: return .object(["resolved": .boolean(true)])
            case .built(let summary): return buildPayload(summary)
            case .cleaned: return .object(["cleaned": .boolean(true)])
            case .reset: return .object(["reset": .boolean(true)])
            case .removed: return .object(["removed": .boolean(true)])
        }
    }

    private func environmentPayload(_ summary: CLIEnvironmentSummary) -> CLIJSONValue {

        .object([
            "packageRoot": .string(summary.packageRoot.path(percentEncoded: false)),
            "toolsVersion": .string(summary.toolsVersion.description),
            "swiftVersion": .string(summary.swiftVersion.description),
            "staticLinuxSDK": .object([
                "identifier": .string(summary.staticLinuxSDKIdentifier),
                "version": .string(summary.staticLinuxSDKVersion)
            ]),
            "requiredComponents": .array(summary.requiredComponents.map { .string(componentName($0)) }),
            "isSwiftlyAvailable": .boolean(summary.isSwiftlyAvailable),
            "isToolchainAvailable": .boolean(summary.isToolchainAvailable),
            "isStaticLinuxSDKAvailable": .boolean(summary.isStaticLinuxSDKAvailable),
            "requiresInstallation": .boolean(summary.requiresInstallation)
        ])
    }

    private func preparedPayload(_ summary: CLIPreparedSummary) -> CLIJSONValue {

        .object([
            "swiftVersion": .string(summary.swiftVersion.description),
            "staticLinuxSDK": .object([
                "identifier": .string(summary.staticLinuxSDKIdentifier),
                "version": .string(summary.staticLinuxSDKVersion)
            ])
        ])
    }

    private func buildPayload(_ summary: CLIBuildSummary) -> CLIJSONValue {

        .object([
            "executable": .string(summary.executable.path(percentEncoded: false)),
            "directory": .string(summary.directory.path(percentEncoded: false)),
            "resourceBundles": .array(summary.resourceBundles.map { .string($0.path(percentEncoded: false)) }),
            "target": .string(targetName(summary.target)),
            "configuration": .string(configurationName(summary.configuration)),
            "swiftVersion": .string(summary.swiftVersion.description),
            "staticLinuxSDK": .object([
                "identifier": .string(summary.staticLinuxSDKIdentifier),
                "version": .string(summary.staticLinuxSDKVersion)
            ]),
            "verification": .string(summary.verification)
        ])
    }

    private func humanSuccess(_ result: CLIResult) -> String {

        switch result {
            case .hostReadiness(let readiness):
                return "Host readiness: \(readinessName(readiness))\n"

            case .commandLineToolsInstallation:
                return "Command Line Tools installation requested.\n"

            case .environments(let values):
                return values
                    .map { "\($0.swiftVersion.description) \($0.staticLinuxSDKIdentifier)" }
                    .joined(separator: "\n") + "\n"

            case .assessment(let summary):
                return humanEnvironment(summary, heading: "Environment assessment")

            case .prepared(let summary):
                return "Prepared environment\n\nSwift: \(summary.swiftVersion.description)\n"
                    + "Static Linux SDK: \(summary.staticLinuxSDKIdentifier)\n"

            case .products(let products):
                return products.joined(separator: "\n") + "\n"

            case .resolved:
                return "Dependencies resolved.\n"

            case .built(let summary):
                return humanBuild(summary)

            case .cleaned:
                return "Build artifacts cleaned.\n"

            case .reset:
                return "Build storage reset.\n"

            case .removed:
                return "Environment resources removed.\n"

            case .preparationRequired:
                return ""
        }
    }

    private func humanEnvironment(_ summary: CLIEnvironmentSummary, heading: String) -> String {

        "\(heading)\n\nPackage: \(summary.packageRoot.path(percentEncoded: false))\n"
            + "Tools version: \(summary.toolsVersion.description)\n"
            + "Swift: \(summary.swiftVersion.description)\n"
            + "Static Linux SDK: \(summary.staticLinuxSDKIdentifier)\n"
            + "Required: \(summary.requiredComponents.map(componentName).joined(separator: ", "))\n"
    }

    private func humanBuild(_ summary: CLIBuildSummary) -> String {

        "Built \(summary.executable.lastPathComponent)\n\n"
            + "Executable: \(summary.executable.path(percentEncoded: false))\n"
            + "Directory: \(summary.directory.path(percentEncoded: false))\n"
            + "Resource bundles: "
            + summary.resourceBundles
                .map { $0.path(percentEncoded: false) }
                .joined(separator: ", ")
            + "\n"
            + "Target: \(targetName(summary.target))\n"
            + "Configuration: \(configurationName(summary.configuration))\n"
            + "Swift: \(summary.swiftVersion.description)\n"
            + "Static Linux SDK: \(summary.staticLinuxSDKIdentifier)\n"
            + "Verification: \(summary.verification)\n"
    }

    private func shellQuote(_ value: String) -> String {

        guard value.range(of: #"^[A-Za-z0-9_./:=+-]+$"#, options: .regularExpression) != nil else {
            return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
        return value
    }

}

extension CLIRenderer {

    private func status(for error: Error) -> Int32 {

        if error is CLIWorkflowError { return 4 }
        guard let error = error as? SwiftlyKitError else { return 1 }
        switch error {
            case .invalidPackageRoot, .invalidSwiftPMEnvironmentVariable, .invalidSwiftPMTrait,
                 .executableProductSelectionRequired, .executableProductNotFound, .invalidBuildJobCount:
                return 2

            case .mutationCoordinationFailed:
                return 7

            case .buildFailed, .packageChangedDuringBuild, .packageSourceStabilityUnavailable:
                return 5

            case .runtimeResourceVerificationFailed, .stripFailed, .executableVerificationFailed, .outputInsideBuildStorage,
                 .outputAlreadyExists, .outputPublicationFailed, .postBuildCleanupFailed:
                return 6

            case .buildArtifactCleanupFailed, .buildStorageResetFailed,
                 .unsafeEnvironmentRemoval, .environmentRemovalFailed:
                return 4

            default:
                return 4
        }
    }

    private func code(for error: Error) -> String {

        guard let error = error as? SwiftlyKitError else { return "internal" }
        switch error {
            case .mutationCoordinationFailed: return "mutationCoordinationFailed"
            case .invalidPackageRoot: return "invalidPackageRoot"
            case .unsupportedHost: return "unsupportedHost"
            case .developerToolsUnavailable: return "developerToolsUnavailable"
            case .commandLineToolsInstallationRequestFailed: return "commandLineToolsInstallationRequestFailed"
            case .malformedToolsVersion: return "malformedToolsVersion"
            case .unsupportedToolsVersion: return "unsupportedToolsVersion"
            case .incompatibleSwiftly: return "incompatibleSwiftly"
            case .swiftlyInstallationFailed: return "swiftlyInstallationFailed"
            case .networkFailure: return "networkFailure"
            case .integrityCheckFailed: return "integrityCheckFailed"
            case .compatibleReleaseUnavailable: return "compatibleReleaseUnavailable"
            case .staticLinuxSDKUnavailable: return "staticLinuxSDKUnavailable"
            case .staleAssessment: return "staleAssessment"
            case .invalidSwiftPMEnvironmentVariable: return "invalidSwiftPMEnvironmentVariable"
            case .invalidSwiftPMTrait: return "invalidSwiftPMTrait"
            case .packageInspectionFailed: return "packageInspectionFailed"
            case .dependencyResolutionRequired: return "dependencyResolutionRequired"
            case .dependencyResolutionFailed: return "dependencyResolutionFailed"
            case .executableProductSelectionRequired: return "executableProductSelectionRequired"
            case .executableProductNotFound: return "executableProductNotFound"
            case .runtimeResourceVerificationFailed: return "runtimeResourceVerificationFailed"
            case .invalidBuildJobCount: return "invalidBuildJobCount"
            case .buildFailed: return "buildFailed"
            case .packageChangedDuringBuild: return "packageChangedDuringBuild"
            case .packageSourceStabilityUnavailable: return "packageSourceStabilityUnavailable"
            case .stripFailed: return "stripFailed"
            case .executableVerificationFailed: return "executableVerificationFailed"
            case .unsafeBuildStorage: return "unsafeBuildStorage"
            case .unsafeSwiftPMSharedStorage: return "unsafeSwiftPMSharedStorage"
            case .unsafeEnvironmentStorage: return "unsafeEnvironmentStorage"
            case .outputInsideBuildStorage: return "outputInsideBuildStorage"
            case .outputAlreadyExists: return "outputAlreadyExists"
            case .outputPublicationFailed: return "outputPublicationFailed"
            case .postBuildCleanupFailed: return "postBuildCleanupFailed"
            case .buildArtifactCleanupFailed: return "buildArtifactCleanupFailed"
            case .buildStorageResetFailed: return "buildStorageResetFailed"
            case .unsafeEnvironmentRemoval: return "unsafeEnvironmentRemoval"
            case .environmentRemovalFailed: return "environmentRemovalFailed"
        }
    }

    private func message(for error: Error) -> String {
        if error is CLIWorkflowError { return "The SwiftlyKit operation could not complete." }
        if error is CancellationError { return "Operation cancelled." }
        return "The SwiftlyKit operation failed."
    }

}

private func readinessName(_ readiness: HostReadiness) -> String {

    switch readiness {
        case .ready: "ready"
        case .developerToolsUnavailable: "developerToolsUnavailable"
        case .unsupportedHost: "unsupportedHost"
    }
}

private func componentName(_ component: PreparationComponent) -> String {

    switch component {
        case .swiftly: "swiftly"
        case .toolchain: "toolchain"
        case .staticLinuxSDK: "staticLinuxSDK"
    }
}

private func targetName(_ target: BuildTarget) -> String {

    switch target {
        case .linux(.x86_64): "x86_64"
        case .linux(.arm64): "aarch64"
    }
}

private func configurationName(_ configuration: BuildConfiguration) -> String {

    switch configuration {
        case .release: "release"
        case .debug: "debug"
    }
}

/// FileHandle-backed process output for the standalone executable.
public final class FileHandleCLIOutput: CLIOutputWriting, @unchecked Sendable {

    private let standardOutput: FileHandle
    private let standardError: FileHandle
    private let lock = NSLock()

    /// Creates an output adapter for the supplied process channels.
    public init(standardOutput: FileHandle = .standardOutput, standardError: FileHandle = .standardError) {
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    /// Whether the process standard-error descriptor is an interactive terminal.
    public var standardErrorIsTTY: Bool { isatty(STDERR_FILENO) == 1 }

    /// Writes one UTF-8 value to standard output.
    public func writeStandardOutput(_ value: String) {
        lock.withLock { try? standardOutput.write(contentsOf: Data(value.utf8)) }
    }

    /// Writes one UTF-8 value to standard error.
    public func writeStandardError(_ value: String) {
        lock.withLock { try? standardError.write(contentsOf: Data(value.utf8)) }
    }

}

/// A small JSON value tree used for compact stable command results.
enum CLIJSONValue: Encodable, Sendable {

    case string(String)
    case boolean(Bool)
    case array([CLIJSONValue])
    case object([String: CLIJSONValue])

    /// Encodes the modeled value through its matching JSON container.
    func encode(to encoder: Encoder) throws {

        var container = encoder.singleValueContainer()
        switch self {
            case .string(let value): try container.encode(value)
            case .boolean(let value): try container.encode(value)
            case .array(let value): try container.encode(value)
            case .object(let value): try container.encode(value)
        }
    }

}

/// Machine-readable command result envelope.
struct CLIJSONEnvelope: Encodable {

    let schemaVersion = 1
    let command: String
    let outcome: String
    let result: CLIJSONValue?
    let preparation: CLIJSONValue?
    let error: CLIJSONValue?

    init(
        command: String,
        outcome: String,
        result: CLIJSONValue? = nil,
        preparation: CLIJSONValue? = nil,
        error: CLIJSONValue? = nil
    ) {

        self.command = command
        self.outcome = outcome
        self.result = result
        self.preparation = preparation
        self.error = error
    }

    /// Encodes the envelope while omitting absent result sections.
    func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(command, forKey: .command)
        try container.encode(outcome, forKey: .outcome)
        try container.encodeIfPresent(result, forKey: .result)
        try container.encodeIfPresent(preparation, forKey: .preparation)
        try container.encodeIfPresent(error, forKey: .error)
    }

    /// Keys emitted in the stable command result envelope.
    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case command
        case outcome
        case result
        case preparation
        case error
    }

}
