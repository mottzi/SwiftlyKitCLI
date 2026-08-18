import Foundation
import Testing
@testable import SwiftlyKitCLI

@Suite("SwiftlyKitCLI signal handling contract", .serialized)
/// Graceful cancellation and repeated-signal behavior.
struct SignalHandlingTests {

    @Test
    /// Verifies the first signal cancels the invocation and a repeat force exits.
    func repeatedSignalsCancelAttachedTaskThenForceExit() async {

        let output = RecordingCLIOutput()
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

}

/// Thread-safe capture of a requested process exit status.
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
