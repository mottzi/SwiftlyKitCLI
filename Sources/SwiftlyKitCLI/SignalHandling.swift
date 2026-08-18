import Darwin
import Dispatch
import Foundation

/// Coordinates graceful cancellation and repeated-signal force exit for one invocation.
actor CLICancellationCoordinator {

    /// Process exit callback used by the repeated-signal path.
    typealias ForceExit = @Sendable (Int32) -> Void

    private let json: Bool
    private let output: any CLIOutputWriting
    private let forceExit: ForceExit
    private var invocationTask: Task<Int32, Never>?
    private var isCancelling = false

    init(json: Bool, output: any CLIOutputWriting, forceExit: @escaping ForceExit) {
        self.json = json
        self.output = output
        self.forceExit = forceExit
    }

    /// Cancels the invocation on the first handled signal and exits on a repeat.
    func receiveSignal() {

        if isCancelling {
            forceExit(130)
            return
        }

        isCancelling = true
        if !json {
            let message = output.standardErrorIsTTY
                ? "\nCancelling… Press Control-C again to force exit.\n"
                : "Cancelling… Press Control-C again to force exit.\n"
            output.writeStandardError(message)
        }
        invocationTask?.cancel()
    }

    /// Registers the invocation task and applies a signal received during setup.
    func attach(invocationTask: Task<Int32, Never>) {
        self.invocationTask = invocationTask
        if isCancelling { invocationTask.cancel() }
    }

}

/// Dispatch signal sources retained for one runtime invocation.
final class CLISignalSources: @unchecked Sendable {

    private let sources: [DispatchSourceSignal]

    /// Creates signal sources for the invocation and ignores handled process signals.
    init(handler: @escaping @Sendable () -> Void) {

        let handledSignals = [SIGINT, SIGTERM, SIGHUP]
        for signalNumber in handledSignals { signal(signalNumber, SIG_IGN) }
        sources = handledSignals.map { signalNumber in
            let source = DispatchSource.makeSignalSource(
                signal: signalNumber,
                queue: DispatchQueue.global(qos: .userInitiated)
            )
            source.setEventHandler(handler: handler)
            return source
        }
    }

    /// Activates all signal sources.
    func activate() {
        for source in sources { source.activate() }
    }

    /// Releases all signal sources.
    func cancel() {
        for source in sources { source.cancel() }
    }

}
