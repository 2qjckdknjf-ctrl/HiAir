import Foundation

/// Deterministic sleep seam for unit tests (avoid real multi-second waits).
protocol Nanosleeping: Sendable {
    func sleep(nanoseconds: UInt64) async
}

struct SystemNanosleeper: Nanosleeping {
    func sleep(nanoseconds: UInt64) async {
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

/// Test sleeper: completes immediately (or after optional cooperative yield).
struct ImmediateNanosleeper: Nanosleeping {
    func sleep(nanoseconds: UInt64) async {
        // Cooperative yield only — never wall-clock sleep.
        await Task.yield()
    }
}

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

/// Controllable async gate for race tests (lock-based; safe with MainActor Tasks).
final class TestAsyncGate: @unchecked Sendable {
    private let lock = NSLock()
    private var opened = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        lock.lock()
        if opened {
            lock.unlock()
            return
        }
        lock.unlock()
        await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                lock.lock()
                if opened || Task.isCancelled {
                    lock.unlock()
                    cont.resume()
                } else {
                    continuation = cont
                    lock.unlock()
                }
            }
        } onCancel: {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume()
        }
    }

    func open() {
        lock.lock()
        opened = true
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume()
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
        sleeper: any Nanosleeping = SystemNanosleeper(),
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
                    await sleeper.sleep(nanoseconds: timeoutNanoseconds)
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
        sleeper: any Nanosleeping = SystemNanosleeper(),
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
                    await sleeper.sleep(nanoseconds: timeoutNanoseconds)
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
