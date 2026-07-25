import XCTest
@testable import HiAir

final class HealthKitTimeoutRaceTests: XCTestCase {
    private let fastSleeper = ImmediateNanosleeper()

    func testCallbackNeverArrives_timeoutReturns() async {
        let outcome: HealthKitTimeoutRace.Outcome<Bool> = await HealthKitTimeoutRace.raceCallback(
            timeoutNanoseconds: 1,
            sleeper: fastSleeper
        ) { (_: @escaping @Sendable (Bool) -> Void) in
            // Never finishes.
        }
        guard case .timedOut = outcome else {
            return XCTFail("Expected timeout")
        }
    }

    func testCallbackBeforeTimeout_returnsValue() async {
        let outcome = await HealthKitTimeoutRace.raceCallback(
            timeoutNanoseconds: 1_000_000_000,
            sleeper: SystemNanosleeper()
        ) { finish in
            finish("ok")
        }
        guard case let .value(value) = outcome else {
            return XCTFail("Expected value")
        }
        XCTAssertEqual(value, "ok")
    }

    func testLateCallbackAfterTimeout_ignoredSafely() async {
        let gate = OneShotCompletionGate<String>()
        var resumeCount = 0
        var lastValue: String?
        gate.wait { value in
            resumeCount += 1
            lastValue = value
        }
        XCTAssertTrue(gate.complete("timeout-winner"))
        XCTAssertFalse(gate.complete("late-callback"))
        XCTAssertEqual(resumeCount, 1)
        XCTAssertEqual(lastValue, "timeout-winner")
        XCTAssertTrue(gate.hasCompleted)
    }

    func testCallbackError_propagatesAsValue() async {
        let error = NSError(domain: "HealthKitTest", code: 1)
        let outcome = await HealthKitTimeoutRace.raceCallback(
            timeoutNanoseconds: 1_000_000_000,
            sleeper: SystemNanosleeper()
        ) { finish in
            finish(error)
        }
        guard case let .value(value) = outcome else {
            return XCTFail("Expected error value")
        }
        XCTAssertEqual((value as NSError).code, 1)
    }

    func testContinuationCompletesExactlyOnce() async {
        let gate = OneShotCompletionGate<Int>()
        var count = 0
        gate.wait { _ in count += 1 }
        XCTAssertTrue(gate.complete(1))
        XCTAssertFalse(gate.complete(2))
        XCTAssertFalse(gate.complete(3))
        XCTAssertEqual(count, 1)
    }

    func testAsyncOperationNeverCompletes_timeoutReturns() async {
        let hang = TestAsyncGate()
        let outcome = await HealthKitTimeoutRace.raceAsync(
            timeoutNanoseconds: 1,
            sleeper: fastSleeper
        ) {
            await hang.wait()
            return "late"
        }
        guard case .timedOut = outcome else {
            return XCTFail("Expected collect timeout")
        }
        await hang.open()
    }

    func testAsyncOperationBeforeTimeout_returnsValue() async {
        let outcome = await HealthKitTimeoutRace.raceAsync(
            timeoutNanoseconds: 1_000_000_000,
            sleeper: SystemNanosleeper()
        ) {
            "snapshots"
        }
        guard case let .value(value) = outcome else {
            return XCTFail("Expected value")
        }
        XCTAssertEqual(value, "snapshots")
    }

    func testLateAsyncAfterTimeout_ignored() async {
        let hang = TestAsyncGate()
        let started = expectation(description: "late work started")
        let outcome = await HealthKitTimeoutRace.raceAsync(
            timeoutNanoseconds: 1,
            sleeper: fastSleeper
        ) {
            started.fulfill()
            await hang.wait()
            return "should-be-ignored"
        }
        guard case .timedOut = outcome else {
            return XCTFail("Expected timeout")
        }
        await fulfillment(of: [started], timeout: 1.0)
        await hang.open()
    }

    func testRetryAfterTimeout_newRaceSucceeds() async {
        let first: HealthKitTimeoutRace.Outcome<Bool> = await HealthKitTimeoutRace.raceCallback(
            timeoutNanoseconds: 1,
            sleeper: fastSleeper
        ) { (_: @escaping @Sendable (Bool) -> Void) in }
        guard case .timedOut = first else {
            return XCTFail("Expected first timeout")
        }
        let second = await HealthKitTimeoutRace.raceCallback(
            timeoutNanoseconds: 1_000_000_000,
            sleeper: SystemNanosleeper()
        ) { finish in
            finish(true)
        }
        guard case let .value(ok) = second else {
            return XCTFail("Expected retry success")
        }
        XCTAssertTrue(ok)
    }

    func testCancellationDoesNotHangCaller() async {
        let hang = TestAsyncGate()
        let parent = Task {
            let _: HealthKitTimeoutRace.Outcome<Bool> = await HealthKitTimeoutRace.raceCallback(
                timeoutNanoseconds: 60_000_000_000,
                sleeper: SystemNanosleeper()
            ) { (_: @escaping @Sendable (Bool) -> Void) in
                // never completes
            }
            _ = hang
        }
        await Task.yield()
        parent.cancel()
        let started = Date()
        _ = await parent.value
        XCTAssertLessThan(Date().timeIntervalSince(started), 1.0)
        await hang.open()
    }
}
