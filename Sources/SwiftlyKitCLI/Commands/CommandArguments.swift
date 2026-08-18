import ArgumentParser
import SwiftlyKit

/// A strict command-line spelling for an exact Swift release.
struct CLISwiftVersionArgument: ExpressibleByArgument, Sendable {

    let value: SwiftVersion

    init?(argument: String) {

        guard let value = SwiftVersion(argument) else { return nil }
        let canonical = value.description
        let shortPatchZero = value.patch == 0 ? "\(value.major).\(value.minor)" : nil
        guard argument == canonical || argument == shortPatchZero else { return nil }
        self.value = value
    }

}

/// The two Linux architectures exposed by SwiftlyKitCLI.
enum CLIArchitecture: String, ExpressibleByArgument, Sendable {

    case x86_64
    case aarch64

    var value: LinuxArchitecture {
        switch self {
            case .x86_64: .x86_64
            case .aarch64: .arm64
        }
    }

}

/// The SwiftPM build configuration exposed by SwiftlyKitCLI.
enum CLIConfiguration: String, ExpressibleByArgument, Sendable {

    case release
    case debug

    var value: BuildConfiguration {
        switch self {
            case .release: .release
            case .debug: .debug
        }
    }

}

/// The post-publication cleanup policy for a build output.
enum CLICleanup: String, ExpressibleByArgument, Sendable {

    case retain
    case clean
    case reset

    var value: BuildCleanup {
        switch self {
            case .retain: .retain
            case .clean: .clean
            case .reset: .reset
        }
    }

}
