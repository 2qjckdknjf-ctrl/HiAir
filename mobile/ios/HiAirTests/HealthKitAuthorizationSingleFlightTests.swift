import XCTest
@testable import HiAir

/// Mirrors HealthKitService authorization single-flight semantics for deterministic tests.
actor AuthorizationSingleFlight {
    private var inFlight: Task<Bool, Never>?
    /// Number of `request` callers currently inside the actor method (owner + joiners).
    private(set) var activeRequestCount = 0

    func request(_ operation: @escaping @Sendable () async -> Bool) async -> Bool {
        activeRequestCount += 1
        defer { activeRequestCount -= 1 }
        if let inFlight {
            return await inFlight.value
        }
        let task = Task { await operation() }
        inFlight = task
        let result = await task.value
        if inFlight == task {
            inFlight = nil
        }
        return result
    }
}

final class HealthKitAuthorizationSingleFlightTests: XCTestCase {
    func testConcurrentConnect_oneOperation() async {
        let flight = AuthorizationSingleFlight()
        let counter = Counter()
        let hold = TestAsyncGate()
        let started = TestAsyncGate()
        async let a = flight.request {
            await counter.increment()
            started.open()
            await hold.wait()
            return true
        }
        await started.wait()
        async let b = flight.request {
            await counter.increment()
            return true
        }
        // Avoid releasing the first op before the second caller has entered `request`
        // (otherwise inFlight is cleared and a second operation starts — CI flake).
        var joined = false
        for _ in 0..<200 {
            if await flight.activeRequestCount >= 2 {
                joined = true
                break
            }
            await Task.yield()
        }
        XCTAssertTrue(joined, "Second concurrent request must enter before first op is released")
        hold.open()
        let results = await (a, b)
        XCTAssertTrue(results.0)
        XCTAssertTrue(results.1)
        let count = await counter.value
        XCTAssertEqual(count, 1)
    }

    func testRetryAfterTimeout_newOperationSucceeds() async {
        let flight = AuthorizationSingleFlight()
        let first = await flight.request { false }
        XCTAssertFalse(first)
        let second = await flight.request { true }
        XCTAssertTrue(second)
    }
}

private actor Counter {
    private(set) var value = 0
    func increment() {
        value += 1
    }
}
