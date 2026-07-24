import Foundation

/// Lightweight runtime probe for P0 UX timings (stages only — no PII / coords / health values).
enum RuntimePerformanceProbe {
    private static let lock = NSLock()
    private static var marks: [String: CFAbsoluteTime] = [:]
    private static var durationsMs: [String: Int] = [:]

    static func begin(_ stage: String) {
        lock.lock()
        marks[stage] = CFAbsoluteTimeGetCurrent()
        lock.unlock()
        StartupDiagnostics.track(stage + "_begin", success: nil)
    }

    @discardableResult
    static func end(_ stage: String, success: Bool = true, errorCode: String? = nil) -> Int {
        lock.lock()
        let started = marks.removeValue(forKey: stage)
        lock.unlock()
        let ms: Int
        if let started {
            ms = Int(((CFAbsoluteTimeGetCurrent() - started) * 1_000).rounded())
        } else {
            ms = -1
        }
        lock.lock()
        durationsMs[stage] = ms
        lock.unlock()
        StartupDiagnostics.track(
            stage + "_end",
            success: success,
            durationMs: ms >= 0 ? ms : nil,
            errorCode: errorCode
        )
        return ms
    }

    static func lastDurationMs(_ stage: String) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        return durationsMs[stage]
    }

    static func snapshot() -> [String: Int] {
        lock.lock()
        defer { lock.unlock() }
        return durationsMs
    }

    #if DEBUG
    static func resetForTests() {
        lock.lock()
        marks.removeAll()
        durationsMs.removeAll()
        lock.unlock()
    }
    #endif
}
