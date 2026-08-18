import Foundation
import SwiftlyKit

/// Coordinates assessment, optional installation, and preparation for staged commands.
func withPreparedEnvironment(
    packageRoot: URL,
    selection: CLIExactEnvironmentOptions,
    preparation: CLIPreparationOptions,
    context: CLICommandContext,
    operation: (SwiftlyKit, LocalBuildEnvironment) async throws -> CLIResult
) async throws -> CLIResult {

    let swiftPMEnvironment = try preparation.swiftPMEnvironment(in: context)
    let swiftPMTraits = try preparation.swiftPMTraits
    let swiftPMSharedStorage = preparation.swiftPMSharedStorage(in: context)

    let swiftlyKit = SwiftlyKit(
        environmentStorage: try selection.environmentStorage(in: context)
    )
    let assessment = try await swiftlyKit.assess(
        packageRoot,
        for: selection.target,
        toolchain: selection.toolchain
    )

    guard !assessment.requiresInstallation || preparation.installEnvironment
    else { return .preparationRequired(CLIEnvironmentSummary(assessment)) }

    let recordRemovalPlan: EnvironmentRemovalPlan.Recorder?
    if let path = preparation.removalPlanPath {
        recordRemovalPlan = try removalPlanRecorder(at: context.canonicalURL(path))
    } else {
        recordRemovalPlan = nil
    }

    let environment = try await swiftlyKit.prepare(
        assessment,
        swiftPMEnvironment: swiftPMEnvironment,
        swiftPMTraits: swiftPMTraits,
        swiftPMSharedStorage: swiftPMSharedStorage,
        recordRemovalPlan: recordRemovalPlan,
        onEvent: context.onEvent
    )
    return try await operation(swiftlyKit, environment)
}

extension CLIPreparationOptions {

    func swiftPMEnvironment(in context: CLICommandContext) throws -> SwiftPMEnvironment {

        let allNames = environmentNames + sensitiveEnvironmentNames + unsetEnvironmentNames
        var seen = Set<String>()
        for name in allNames {
            guard seen.insert(name).inserted else {
                throw CLIInputError.duplicateEnvironment(name)
            }
        }

        var values: [String: SwiftPMEnvironment.Value] = [:]
        for name in environmentNames {
            guard let value = context.environment[name] else {
                throw CLIInputError.missingEnvironmentValue(name)
            }
            values[name] = .plain(value)
        }
        for name in sensitiveEnvironmentNames {
            guard let value = context.environment[name] else {
                throw CLIInputError.missingEnvironmentValue(name)
            }
            values[name] = .sensitive(value)
        }
        for name in unsetEnvironmentNames { values[name] = .unset }
        return try SwiftPMEnvironment(values)
    }

    var swiftPMTraits: SwiftPMTraits {
        get throws {
            if noTraits { return .none }
            if allTraits { return .all }
            guard !traits.isEmpty else { return .packageDefaults }
            return try SwiftPMTraits(traits, includingDefaults: includeDefaultTraits)
        }
    }

    func swiftPMSharedStorage(in context: CLICommandContext) -> SwiftPMSharedStorage {

        SwiftPMSharedStorage(
            cacheDirectory: cachePath.map(context.canonicalURL),
            configurationDirectory: swiftPMConfigurationPath.map(context.canonicalURL),
            securityDirectory: securityPath.map(context.canonicalURL)
        )
    }

}

private func removalPlanRecorder(at path: URL) throws -> EnvironmentRemovalPlan.Recorder {

    let parent = path.deletingLastPathComponent()
    
    var isDirectory: ObjCBool = false
    let parentExists = FileManager.default.fileExists(
        atPath: parent.path(percentEncoded: false),
        isDirectory: &isDirectory
    )
    
    guard parentExists,
          isDirectory.boolValue
    else { throw CLIWorkflowError.removalPlanParentMissing(parent) }

    let recorder: EnvironmentRemovalPlan.Recorder = { plan in
        do {
            let data = try JSONEncoder().encode(plan)
            try data.write(to: path, options: .atomic)
        } catch {
            throw CLIWorkflowError.removalPlanWriteFailed(path)
        }
    }
    
    return recorder
}
