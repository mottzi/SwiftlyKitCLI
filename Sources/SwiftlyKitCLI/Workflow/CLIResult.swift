import Foundation
import SwiftlyKit

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

}

extension CLIEnvironmentSummary {

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
