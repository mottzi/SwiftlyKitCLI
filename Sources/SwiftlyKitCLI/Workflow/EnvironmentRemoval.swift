import Foundation
import SwiftlyKit

/// Builds a removal plan from one command's file or exact resource options.
func removalPlan(for command: RemoveCommand, in context: CLICommandContext) throws -> EnvironmentRemovalPlan {

    if let path = command.removalPlanPath {
        let url = context.canonicalURL(path)
        do {
            return try JSONDecoder().decode(
                EnvironmentRemovalPlan.self,
                from: Data(contentsOf: url)
            )
        } catch {
            throw CLIInputError.invalidRemovalPlan(url)
        }
    }

    let storage: EnvironmentStorage = if let path = command.environmentStoragePath {
        .directory(context.canonicalURL(path))
    } else {
        .standard
    }

    switch (command.swiftVersion?.value, command.sdkIdentifier) {
        case let (.some(version), .some(identifier)):
            return try EnvironmentRemovalPlan.environment(
                toolchain: version,
                staticLinuxSDKIdentifier: identifier,
                in: storage
            )

        case let (.some(version), nil):
            return .toolchain(version, in: storage)

        case let (nil, .some(identifier)):
            return try EnvironmentRemovalPlan.staticLinuxSDK(identifier: identifier, in: storage)

        case (nil, nil):
            throw CLIInputError.emptyRemovalSpecification
    }
}
