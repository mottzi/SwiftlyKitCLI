import Foundation

/// Errors raised while writing an explicit removal-plan record.
enum CLIWorkflowError: Error, LocalizedError, Sendable {

    case removalPlanParentMissing(URL)
    case removalPlanWriteFailed(URL)

    var errorDescription: String? {
        switch self {
            case .removalPlanParentMissing(let url):
                "The removal-plan parent directory does not exist: \(url.path(percentEncoded: false))."

            case .removalPlanWriteFailed(let url):
                "The removal plan could not be written: \(url.path(percentEncoded: false))."

        }
    }

}

/// CLI-only input conversion failures.
enum CLIInputError: Error, LocalizedError, Sendable {

    case duplicateEnvironment(String)
    case missingEnvironmentValue(String)
    case invalidRemovalPlan(URL)
    case emptyRemovalSpecification

    var errorDescription: String? {
        switch self {
            case .duplicateEnvironment(let name):
                "The environment variable ‘\(name)’ was requested more than once."

            case .missingEnvironmentValue(let name):
                "The environment variable ‘\(name)’ is not present in this process."

            case .invalidRemovalPlan(let url):
                "The removal plan is invalid: \(url.path(percentEncoded: false))."

            case .emptyRemovalSpecification:
                "Provide a removal-plan path, --swift-version, or --sdk-identifier."
        }
    }

}
