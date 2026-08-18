import Foundation
import Testing
@testable import SwiftlyKitCLI
import SwiftlyKit

@Suite("SwiftlyKitCLI runtime contract", .serialized)
/// Request translation, outcome rendering, and preflight validation at the CLI seam.
struct SwiftlyKitCLIRuntimeTests {

    @Test
    /// Verifies the build command maps its supported options to one SwiftlyKit request.
    func buildRequestMapsSupportedOptions() async throws {

        let package = try makePackage()
        defer { try? FileManager.default.removeItem(at: package) }
        let recorder = RequestRecorder()
        let runtime = makeRuntime(
            currentDirectory: package,
            environment: ["TOKEN": "plain", "SECRET": "secret"],
            recorder: recorder
        )
        let arguments = [
            "build", "--swift-version", "6.0.0", "--architecture", "aarch64",
            "--configuration", "debug", "--product", "Server", "--jobs", "3",
            "--trait", "FeatureA", "--include-default-traits",
            "--environment", "TOKEN", "--sensitive-environment", "SECRET",
            "--unset-environment", "REMOVE", "--environment-storage-path", "Environment",
            "--scratch-path", "Scratch", "--cache-path", "Cache",
            "--swiftpm-configuration-path", "Configuration", "--security-path", "Security",
            "--install-environment", "--removal-plan", "Removal.json",
            "--output-path", "Output", "--replace-output", "--cleanup", "reset",
            "--strip", "--resolve-dependencies", "--json"
        ]

        let output = RuntimeRecordingOutput()
        let status = await runtime.run(arguments: arguments, output: output)

        #expect(status == 0, "status=\(status), stdout=\(output.standardOutput), stderr=\(output.standardError)")
        let request = try #require(await recorder.lastRequest())
        #expect(operationName(request.operation) == "build")
        #expect(request.packageRoot == package.standardizedFileURL)
        guard case .linux(.arm64) = request.target else {
            Issue.record("The build target must use aarch64.")
            return
        }
        guard case .exact(let version) = request.toolchain else {
            Issue.record("The build must use an exact Swift release.")
            return
        }
        #expect(version == SwiftVersion(major: 6, minor: 0, patch: 0))
        guard case .debug = request.configuration else {
            Issue.record("The build must use debug configuration.")
            return
        }
        #expect(request.product == "Server")
        #expect(request.jobs == 3)
        #expect(request.scratchStorage == .directory(package.appending(path: "Scratch")))
        #expect(request.strip)
        #expect(request.resolveDependencies)
        #expect(request.installEnvironment)
        #expect(request.environmentStorage == .directory(package.appending(path: "Environment")))
        #expect(request.removalPlanPath == package.appending(path: "Removal.json"))
        guard case .publish(let path, true, .reset) = request.output else {
            Issue.record("The build must publish with replacement and reset cleanup.")
            return
        }
        #expect(path == package.appending(path: "Output"))
        #expect(request.json)
        #expect(!request.verbose)
        #expect(output.standardError.isEmpty)
    }

    @Test
    /// Verifies every declared command reaches the single workflow client.
    func everyCommandUsesTheWorkflowSeam() async throws {

        let package = try makePackage()
        defer { try? FileManager.default.removeItem(at: package) }
        let forms: [([String], String)] = [
            (["host-readiness"], "hostReadiness"),
            (["install-command-line-tools"], "installCommandLineTools"),
            (["environments", package.path], "environments"),
            (["assess", package.path], "assess"),
            (["prepare", package.path], "prepare"),
            (["products", package.path], "products"),
            (["resolve", package.path], "resolve"),
            (["build", package.path], "build"),
            (["clean", package.path], "clean"),
            (["reset", package.path], "reset"),
            (["remove", "--swift-version", "6.0"] , "remove")
        ]

        for (arguments, expectedOperation) in forms {
            let recorder = RequestRecorder()
            let runtime = makeRuntime(currentDirectory: package, recorder: recorder)
            let output = RuntimeRecordingOutput()
            let status = await runtime.run(arguments: arguments, output: output)

            #expect(
                status == 0,
                "Command failed: \(arguments), stdout=\(output.standardOutput), stderr=\(output.standardError)"
            )
            let request = try #require(await recorder.lastRequest())
            #expect(operationName(request.operation) == expectedOperation)
        }
    }

    @Test
    /// Verifies invalid options fail before the injected workflow client is called.
    func invalidRequestsBypassWorkflow() async throws {

        let package = try makePackage()
        defer { try? FileManager.default.removeItem(at: package) }
        let forms = [
            ["build", package.path, "--verbose", "--json"],
            ["remove", "--swift-version", "6.0", "--verbose", "--json"],
            ["build", package.path, "--jobs", "0"],
            ["build", package.path, "--architecture", "arm64"],
            ["build", package.path, "--architecture", "amd64"],
            ["build", package.path, "--configuration", "optimized"],
            ["build", package.path, "--trait", "Feature", "--no-traits"],
            ["build", package.path, "--trait", "Feature", "--all-traits"],
            ["build", package.path, "--include-default-traits"],
            ["build", package.path, "--environment", "TOKEN", "--environment", "TOKEN"],
            ["build", package.path, "--environment", "1TOKEN"],
            ["build", package.path, "--environment", "TOKEN=bad"],
            ["build", package.path, "--cleanup", "clean"],
            ["build", package.path, "--replace-output"],
            ["remove", "Removal.json", "--swift-version", "6.0"]
        ]

        for arguments in forms {
            let recorder = RequestRecorder()
            let runtime = makeRuntime(
                currentDirectory: package,
                environment: ["1TOKEN": "value"],
                recorder: recorder
            )
            let output = RuntimeRecordingOutput()
            let status = await runtime.run(arguments: arguments, output: output)

            #expect(status == 2, "Invalid form returned the wrong status: \(arguments)")
            #expect(await recorder.count() == 0)
            #expect(output.standardOutput.isEmpty || arguments.contains("--json"))
        }
    }

    @Test
    /// Verifies package-root validation runs before environment-name validation.
    func packageValidationPrecedesEnvironmentValidation() async {

        let recorder = RequestRecorder()
        let runtime = makeRuntime(
            currentDirectory: URL(filePath: "/tmp/swiftlykitcli-missing-package"),
            environment: [:],
            recorder: recorder
        )
        let output = RuntimeRecordingOutput()
        let status = await runtime.run(
            arguments: ["build", "missing", "--environment", "MISSING", "--json"],
            output: output
        )

        #expect(status == 2)
        #expect(await recorder.count() == 0)
        #expect(output.standardError.isEmpty)
        #expect(output.standardOutput.filter { $0 == "\n" }.count == 1)
        #expect(output.standardOutput.contains("invalidPackageRoot"))
    }

    @Test
    /// Verifies a versioned removal-plan file reaches the remove request unchanged.
    func removalPlanFileReachesWorkflow() async throws {

        let package = try makePackage()
        defer { try? FileManager.default.removeItem(at: package) }
        let planPath = package.appending(path: "Removal.json")
        let plan = EnvironmentRemovalPlan.toolchain(SwiftVersion(major: 6, minor: 0, patch: 0))
        try JSONEncoder().encode(plan).write(to: planPath)
        let recorder = RequestRecorder()
        let runtime = makeRuntime(currentDirectory: package, recorder: recorder)
        let status = await runtime.run(
            arguments: ["remove", planPath.path],
            output: RuntimeRecordingOutput()
        )

        #expect(status == 0)
        let request = try #require(await recorder.lastRequest())
        #expect(operationName(request.operation) == "remove")
        #expect(request.removalPlan != nil)
    }

    @Test
    /// Verifies stable status classes for representative SwiftlyKit failures.
    func failureCategoriesMapToStableStatuses() async throws {

        let failures: [(SwiftlyKitError, Int32, String)] = [
            (.invalidPackageRoot(URL(filePath: "/missing")), 2, "invalidPackageRoot"),
            (.developerToolsUnavailable, 4, "developerToolsUnavailable"),
            (.buildArtifactCleanupFailed("failed"), 4, "buildArtifactCleanupFailed"),
            (.buildStorageResetFailed("failed"), 4, "buildStorageResetFailed"),
            (.environmentRemovalFailed("failed"), 4, "environmentRemovalFailed"),
            (.runtimeResourceVerificationFailed, 6, "runtimeResourceVerificationFailed"),
            (.buildFailed("failed"), 5, "buildFailed"),
            (.executableVerificationFailed("failed"), 6, "executableVerificationFailed"),
            (.mutationCoordinationFailed("busy"), 7, "mutationCoordinationFailed")
        ]

        for (failure, expectedStatus, expectedCode) in failures {
            let client = SwiftlyKitCLIWorkflowClient { _, _ in throw failure }
            let runtime = SwiftlyKitCLIRuntime(
                version: "test",
                environment: [:],
                currentDirectory: URL(filePath: "/tmp"),
                workflowClient: client
            )
            let output = RuntimeRecordingOutput()
            let status = await runtime.run(
                arguments: ["host-readiness", "--json"],
                output: output
            )

            #expect(status == expectedStatus)
            #expect(output.standardError.isEmpty)
            #expect(output.standardOutput.filter { $0 == "\n" }.count == 1)
            #expect(output.standardOutput.contains("\"code\":\"\(expectedCode)\""))
        }
    }

    @Test
    /// Verifies an unexpected SwiftlyKit error maps to the internal failure status.
    func unexpectedFailureMapsToStatusOne() async {

        let client = SwiftlyKitCLIWorkflowClient { _, _ in throw TestInternalError() }
        let runtime = SwiftlyKitCLIRuntime(
            version: "test",
            environment: [:],
            currentDirectory: URL(filePath: "/tmp"),
            workflowClient: client
        )
        let output = RuntimeRecordingOutput()
        let status = await runtime.run(arguments: ["host-readiness", "--json"], output: output)

        #expect(status == 1)
        #expect(output.standardError.isEmpty)
        #expect(output.standardOutput.contains("\"code\":\"internal\""))
    }

    @Test
    /// Verifies the first signal cancels the invocation and a repeat force exits.
    func repeatedSignalsCancelAttachedTaskThenForceExit() async {

        let output = RuntimeRecordingOutput()
        let forceExit = ForceExitRecorder()
        let coordinator = CLICancellationCoordinator(
            json: true,
            output: output,
            forceExit: { status in forceExit.record(status) }
        )
        let task = Task<Int32, Never> {
            while !Task.isCancelled {
                await Task.yield()
            }
            return 130
        }
        await coordinator.attach(invocationTask: task)

        await coordinator.receiveSignal()
        #expect(task.isCancelled)

        await coordinator.receiveSignal()
        #expect(forceExit.status == 130)
        task.cancel()
        _ = await task.value
    }

    @Test
    /// Verifies human success uses stdout and JSON success emits one compact envelope.
    func successChannelsRemainExclusive() async {

        for arguments in [["host-readiness"], ["host-readiness", "--json"]] {
            let runtime = makeRuntime(recorder: RequestRecorder())
            let output = RuntimeRecordingOutput()
            let status = await runtime.run(arguments: arguments, output: output)

            #expect(status == 0)
            #expect(output.standardError.isEmpty)
            #expect(output.standardOutput.filter { $0 == "\n" }.count == 1)
            if arguments.contains("--json") {
                #expect(output.standardOutput.contains("\"schemaVersion\":1"))
                #expect(output.standardOutput.contains("\"outcome\":\"success\""))
            } else {
                #expect(output.standardOutput == "Host readiness: ready\n")
            }
        }
    }

    @Test
    /// Verifies preparation-required results use status three and the correct output channel.
    func preparationRequiredUsesHumanAndJSONContracts() async throws {

        let package = try makePackage()
        defer { try? FileManager.default.removeItem(at: package) }
        let summary = CLIEnvironmentSummary(
            packageRoot: package,
            toolsVersion: SwiftVersion(major: 6, minor: 0, patch: 0),
            swiftVersion: SwiftVersion(major: 6, minor: 0, patch: 0),
            staticLinuxSDKIdentifier: "swift-6.0.0-RELEASE_static-linux",
            staticLinuxSDKVersion: "6.0.0",
            requiredComponents: [.swiftly, .toolchain, .staticLinuxSDK],
            isSwiftlyAvailable: false,
            isToolchainAvailable: false,
            isStaticLinuxSDKAvailable: false,
            requiresInstallation: true
        )
        let modes = [(false, "human"), (true, "json")]

        for (json, mode) in modes {
            let client = SwiftlyKitCLIWorkflowClient { _, _ in
                .preparationRequired(summary)
            }
            let runtime = SwiftlyKitCLIRuntime(
                version: "test",
                environment: [:],
                currentDirectory: package,
                workflowClient: client
            )
            let output = RuntimeRecordingOutput()
            let status = await runtime.run(
                arguments: ["build", package.path] + (json ? ["--json"] : []),
                output: output
            )

            #expect(status == 3, "Preparation mode failed: \(mode)")
            #expect(output.standardOutput.isEmpty == !json)
            #expect(output.standardError.isEmpty == json)
            if json {
                #expect(output.standardOutput.filter { $0 == "\n" }.count == 1)
                let data = try #require(output.standardOutput.data(using: .utf8))
                let document = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
                #expect(document["schemaVersion"] as? Int == 1)
                #expect(document["command"] as? String == "build")
                #expect(document["outcome"] as? String == "preparationRequired")
                let preparation = try #require(document["preparation"] as? [String: Any])
                #expect(preparation["swiftVersion"] as? String == "6.0.0")
                let sdk = try #require(preparation["staticLinuxSDK"] as? [String: Any])
                #expect(sdk["identifier"] as? String == "swift-6.0.0-RELEASE_static-linux")
                #expect(sdk["version"] as? String == "6.0.0")
            } else {
                #expect(output.standardError.contains("action required:"))
                #expect(output.standardError.contains("--install-environment"))
            }
        }
    }

    @Test
    /// Verifies cancellation uses status 130 and one terminal JSON document.
    func cancellationHasOneTerminalOutcome() async {

        for json in [false, true] {
            let client = SwiftlyKitCLIWorkflowClient { _, _ in throw CancellationError() }
            let runtime = SwiftlyKitCLIRuntime(
                version: "test",
                environment: [:],
                currentDirectory: URL(filePath: "/tmp"),
                workflowClient: client
            )
            let output = RuntimeRecordingOutput()
            let status = await runtime.run(
                arguments: ["host-readiness"] + (json ? ["--json"] : []),
                output: output
            )

            #expect(status == 130)
            #expect(output.standardOutput.isEmpty == !json)
            #expect(output.standardError.isEmpty == json)
            #expect(output.standardOutput.filter { $0 == "\n" }.count == (json ? 1 : 0))
            if !json {
                #expect(output.standardError.contains("cancelled: Operation cancelled."))
            }
        }
    }

}

private func makeRuntime(
    currentDirectory: URL = URL(filePath: "/tmp"),
    environment: [String: String] = [:],
    recorder: RequestRecorder,
    result: CLIResult = .hostReadiness(.ready)
) -> SwiftlyKitCLIRuntime {

    let client = SwiftlyKitCLIWorkflowClient { request, _ in
        await recorder.record(request)
        return result
    }
    return SwiftlyKitCLIRuntime(
        version: "test",
        environment: environment,
        currentDirectory: currentDirectory,
        workflowClient: client
    )
}

private func makePackage() throws -> URL {

    let package = FileManager.default.temporaryDirectory
        .appending(path: "SwiftlyKitCLI-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
    try Data("// swift-tools-version: 6.0\n".utf8)
        .write(to: package.appending(path: "Package.swift"))
    return package.standardizedFileURL
}

private func operationName(_ operation: CLIRequestOperation) -> String {

    switch operation {
        case .hostReadiness: "hostReadiness"
        case .installCommandLineTools: "installCommandLineTools"
        case .environments: "environments"
        case .assess: "assess"
        case .prepare: "prepare"
        case .products: "products"
        case .resolve: "resolve"
        case .build: "build"
        case .clean: "clean"
        case .reset: "reset"
        case .remove: "remove"
    }
}

/// Thread-safe capture of requests crossing the CLI workflow seam.
private actor RequestRecorder {

    private var requests: [CLIRequest] = []

    func record(_ request: CLIRequest) {
        requests.append(request)
    }

    func count() -> Int {
        requests.count
    }

    func lastRequest() -> CLIRequest? {
        requests.last
    }

}

/// Lock-protected capture of the runtime's standard output and error channels.
private final class RuntimeRecordingOutput: CLIOutputWriting, @unchecked Sendable {

    private let lock = NSLock()
    private var recordedStandardOutput = ""
    private var recordedStandardError = ""

    var standardOutput: String {
        lock.withLock { recordedStandardOutput }
    }

    var standardError: String {
        lock.withLock { recordedStandardError }
    }

    func writeStandardOutput(_ value: String) {
        lock.withLock { recordedStandardOutput += value }
    }

    func writeStandardError(_ value: String) {
        lock.withLock { recordedStandardError += value }
    }

}

/// Lock-protected capture of a requested process exit status.
private final class ForceExitRecorder: @unchecked Sendable {

    private let lock = NSLock()
    private var recordedStatus: Int32?

    var status: Int32? {
        lock.withLock { recordedStatus }
    }

    func record(_ status: Int32) {
        lock.withLock { recordedStatus = status }
    }

}

/// Unexpected failure used to verify the catastrophic status mapping.
private struct TestInternalError: Error, Sendable {}
