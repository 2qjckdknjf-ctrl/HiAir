import Foundation

/// One-shot completion gate: resumes a waiter exactly once; late completions are ignored.
final class OneShotCompletionGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private var stored: Value?
    private var waiter: ((Value) -> Void)?

    func wait(_ handler: @escaping (Value) -> Void) {
        lock.lock()
        if completed {
            let value = stored
            lock.unlock()
            if let value {
                handler(value)
            }
            return
        }
        waiter = handler
        lock.unlock()
    }

    @discardableResult
    func complete(_ value: Value) -> Bool {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return false
        }
        completed = true
        stored = value
        let handler = waiter
        waiter = nil
        lock.unlock()
        handler?(value)
        return true
    }

    var hasCompleted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return completed
    }
}

/// Timeout race that returns without awaiting a hung callback / child task.
enum HealthKitTimeoutRace {
    enum Outcome<Value> {
        case value(Value)
        case timedOut
    }

    /// Race a callback-style operation against a timeout.
    /// Late callbacks after timeout are ignored (no double resume).
    /// Caller cancellation completes immediately with `.timedOut`.
    static func raceCallback<Value: Sendable>(
        timeoutNanoseconds: UInt64,
        operation: @escaping (@escaping @Sendable (Value) -> Void) -> Void
    ) async -> Outcome<Value> {
        let gate = OneShotCompletionGate<Outcome<Value>>()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Outcome<Value>, Never>) in
                gate.wait { outcome in
                    continuation.resume(returning: outcome)
                }

                operation { value in
                    _ = gate.complete(.value(value))
                }

                Task {
                    try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                    _ = gate.complete(.timedOut)
                }
            }
        } onCancel: {
            _ = gate.complete(.timedOut)
        }
    }

    /// Race an async operation against a timeout without awaiting a hung operation after timeout.
    static func raceAsync<Value: Sendable>(
        timeoutNanoseconds: UInt64,
        operation: @escaping @Sendable () async -> Value
    ) async -> Outcome<Value> {
        let gate = OneShotCompletionGate<Outcome<Value>>()
        let work = Task {
            let value = await operation()
            _ = gate.complete(.value(value))
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Outcome<Value>, Never>) in
                gate.wait { outcome in
                    continuation.resume(returning: outcome)
                }

                Task {
                    try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                    work.cancel()
                    _ = gate.complete(.timedOut)
                }
            }
        } onCancel: {
            work.cancel()
            _ = gate.complete(.timedOut)
        }
    }
}
