import XCTest
@testable import HiAir

/// Mirrors HealthKitService authorization single-flight semantics for deterministic tests.
actor AuthorizationSingleFlight {
    private var inFlight: Task<Bool, Never>?

    func request(_ operation: @escaping @Sendable () async -> Bool) async -> Bool {
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
        async let a = flight.request {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 40_000_000)
            return true
        }
        async let b = flight.request {
            await counter.increment()
            return true
        }
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
