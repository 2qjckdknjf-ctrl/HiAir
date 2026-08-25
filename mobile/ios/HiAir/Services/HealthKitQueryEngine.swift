import Foundation
import HealthKit

/// Off-MainActor HealthKit reads. `HKHealthStore` is thread-safe; running queries
/// concurrently is what makes connect/sync feel instant instead of 20+ serial round-trips.
enum HealthKitQueryEngine {
    private static let bpm = HKUnit.count().unitDivided(by: .minute())
    private static let workoutType = HKObjectType.workoutType()
    private static let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
    private static let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession)

    nonisolated static func collectToday(
        store: HKHealthStore,
        tiers: Set<Int>,
        start: Date,
        end: Date,
        calendar: Calendar
    ) async -> ([HealthMetricSnapshot], HealthSleepSnapshot?) {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: start) ?? start
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: start) ?? start
        let ninetyAgo = calendar.date(byAdding: .day, value: -90, to: start) ?? start

        return await withTaskGroup(of: CollectPiece.self) { group in
            if tiers.contains(1) {
                group.addTask { .snapshots(await cumulative(store, .stepCount, "steps", .count(), "count", start, end)) }
                group.addTask { .snapshots(await cumulative(store, .distanceWalkingRunning, "distance_walking_running", .meter(), "m", start, end)) }
                group.addTask { .snapshots(await cumulative(store, .activeEnergyBurned, "active_energy", .kilocalorie(), "kcal", start, end)) }
                group.addTask { .snapshots(await cumulative(store, .basalEnergyBurned, "basal_energy", .kilocalorie(), "kcal", start, end)) }
                group.addTask { .snapshots(await cumulative(store, .appleExerciseTime, "exercise_minutes", .minute(), "min", start, end)) }
                group.addTask { .snapshots(await cumulative(store, .appleStandTime, "stand_minutes", .minute(), "min", start, end)) }
                group.addTask { .snapshots(await cumulative(store, .flightsClimbed, "flights_climbed", .count(), "count", start, end)) }
                group.addTask { .snapshots(await workouts(store, start: start, end: end)) }
                group.addTask { .sleep(await sleep(store, dayStart: start, calendar: calendar)) }
            }
            if tiers.contains(2) {
                group.addTask { .snapshots(compact(await discrete(store, .heartRate, "heart_rate", bpm, "bpm", start, end))) }
                group.addTask { .snapshots(compact(await latest(store, .restingHeartRate, "resting_heart_rate", bpm, "bpm", yesterday, end))) }
                group.addTask { .snapshots(compact(await latest(store, .walkingHeartRateAverage, "walking_heart_rate_avg", bpm, "bpm", weekAgo, end))) }
                group.addTask { .snapshots(compact(await discrete(store, .heartRateVariabilitySDNN, "hrv_sdnn", .secondUnit(with: .milli), "ms", start, end, hrvMethod: "sdnn"))) }
                group.addTask { .snapshots(compact(await latest(store, .vo2Max, "vo2_max", HKUnit(from: "ml/kg*min"), "ml_kg_min", ninetyAgo, end))) }
                group.addTask { .snapshots(compact(await mindfulness(store, start: start, end: end))) }
                group.addTask { .snapshots(compact(await latest(store, .walkingSpeed, "walking_speed", .meter().unitDivided(by: .second()), "m_s", weekAgo, end))) }
                group.addTask { .snapshots(compact(await latest(store, .walkingStepLength, "walking_step_length", .meter(), "m", weekAgo, end))) }
                group.addTask { .snapshots(compact(await latest(store, .walkingAsymmetryPercentage, "walking_asymmetry", .percent(), "percent", weekAgo, end, scale: 100))) }
                group.addTask { .snapshots(compact(await latest(store, .walkingDoubleSupportPercentage, "walking_double_support", .percent(), "percent", weekAgo, end, scale: 100))) }
            }
            if tiers.contains(3) {
                group.addTask { .snapshots(compact(await discrete(store, .respiratoryRate, "respiratory_rate", bpm, "breaths_per_min", start, end))) }
                group.addTask { .snapshots(compact(await discrete(store, .oxygenSaturation, "oxygen_saturation", .percent(), "percent", start, end, scale: 100))) }
                group.addTask { .snapshots(compact(await latest(store, .bodyTemperature, "body_temperature", .degreeCelsius(), "celsius", weekAgo, end))) }
                group.addTask { .snapshots(compact(await latest(store, .appleSleepingWristTemperature, "wrist_temperature", .degreeCelsius(), "celsius", weekAgo, end))) }
            }

            var snapshots: [HealthMetricSnapshot] = []
            var sleepSnap: HealthSleepSnapshot?
            for await piece in group {
                switch piece {
                case .snapshots(let items):
                    snapshots.append(contentsOf: items)
                case .sleep(let value):
                    sleepSnap = value
                }
            }
            return (snapshots, sleepSnap)
        }
    }

    nonisolated static func hourlyActivity(
        store: HKHealthStore,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async -> [(hourStart: Date, steps: Int, hrAvg: Double?, hrMax: Double?)] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        let hourStartBase = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)
        return await withTaskGroup(of: (Int, Date, Int, Double?, Double?).self) { group in
            for offset in 0..<24 {
                group.addTask {
                    let hourStart = calendar.date(byAdding: .hour, value: -offset, to: hourStartBase) ?? hourStartBase
                    let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? hourStart
                    let predicate = HKQuery.predicateForSamples(withStart: hourStart, end: hourEnd, options: .strictStartDate)
                    let steps = Int((await sumQuantity(store, type: stepType, unit: .count(), predicate: predicate) ?? 0).rounded())
                    var hrAvg: Double?
                    var hrMax: Double?
                    if let hrType {
                        let stats = await statistics(
                            store,
                            type: hrType,
                            predicate: predicate,
                            options: [.discreteAverage, .discreteMax]
                        )
                        hrAvg = stats?.averageQuantity()?.doubleValue(for: bpm)
                        hrMax = stats?.maximumQuantity()?.doubleValue(for: bpm)
                    }
                    return (offset, hourStart, steps, hrAvg, hrMax)
                }
            }
            var rows: [(Int, Date, Int, Double?, Double?)] = []
            rows.reserveCapacity(24)
            for await row in group {
                rows.append(row)
            }
            return rows.sorted { $0.0 < $1.0 }.map { (_, start, steps, avg, max) in
                (hourStart: start, steps: steps, hrAvg: avg, hrMax: max)
            }
        }
    }

    private enum CollectPiece: Sendable {
        case snapshots([HealthMetricSnapshot])
        case sleep(HealthSleepSnapshot?)
    }

    private static func compact(_ snapshot: HealthMetricSnapshot?) -> [HealthMetricSnapshot] {
        snapshot.map { [$0] } ?? []
    }

    private static func cumulative(
        _ store: HKHealthStore,
        _ id: HKQuantityTypeIdentifier,
        _ metric: String,
        _ unit: HKUnit,
        _ unitName: String,
        _ start: Date,
        _ end: Date
    ) async -> [HealthMetricSnapshot] {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else {
            return [unsupported(metric, unitName)]
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        if let total = await sumQuantity(store, type: type, unit: unit, predicate: predicate) {
            return [HealthMetricSnapshot(
                metricType: metric, unit: unitName, valueAvg: nil, valueMin: nil, valueMax: nil,
                valueLatest: nil, valueTotal: total, sampleCount: 1, qualityState: "ok", hrvMethod: nil
            )]
        }
        return [HealthMetricSnapshot(
            metricType: metric, unit: unitName, valueAvg: nil, valueMin: nil, valueMax: nil,
            valueLatest: nil, valueTotal: nil, sampleCount: 0, qualityState: "no_records", hrvMethod: nil
        )]
    }

    private static func discrete(
        _ store: HKHealthStore,
        _ id: HKQuantityTypeIdentifier,
        _ metric: String,
        _ unit: HKUnit,
        _ unitName: String,
        _ start: Date,
        _ end: Date,
        hrvMethod: String? = nil,
        scale: Double = 1
    ) async -> HealthMetricSnapshot? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else {
            return unsupported(metric, unitName, hrvMethod: hrvMethod)
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let stats = await statistics(
            store,
            type: type,
            predicate: predicate,
            options: [.discreteAverage, .discreteMin, .discreteMax]
        )
        let avg = stats?.averageQuantity()?.doubleValue(for: unit)
        let min = stats?.minimumQuantity()?.doubleValue(for: unit)
        let max = stats?.maximumQuantity()?.doubleValue(for: unit)
        guard avg != nil || min != nil || max != nil else {
            return HealthMetricSnapshot(
                metricType: metric, unit: unitName, valueAvg: nil, valueMin: nil, valueMax: nil,
                valueLatest: nil, valueTotal: nil, sampleCount: 0, qualityState: "no_records", hrvMethod: hrvMethod
            )
        }
        let latest = await latestSample(store, type: type, predicate: predicate)?.quantity.doubleValue(for: unit)
        return HealthMetricSnapshot(
            metricType: metric,
            unit: unitName,
            valueAvg: avg.map { $0 * scale },
            valueMin: min.map { $0 * scale },
            valueMax: max.map { $0 * scale },
            valueLatest: (latest ?? avg).map { $0 * scale },
            valueTotal: nil,
            sampleCount: 1,
            qualityState: "ok",
            hrvMethod: hrvMethod
        )
    }

    private static func latest(
        _ store: HKHealthStore,
        _ id: HKQuantityTypeIdentifier,
        _ metric: String,
        _ unit: HKUnit,
        _ unitName: String,
        _ start: Date,
        _ end: Date,
        scale: Double = 1
    ) async -> HealthMetricSnapshot? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else {
            return unsupported(metric, unitName)
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        guard let sample = await latestSample(store, type: type, predicate: predicate) else {
            return HealthMetricSnapshot(
                metricType: metric, unit: unitName, valueAvg: nil, valueMin: nil, valueMax: nil,
                valueLatest: nil, valueTotal: nil, sampleCount: 0, qualityState: "no_records", hrvMethod: nil
            )
        }
        let value = sample.quantity.doubleValue(for: unit) * scale
        return HealthMetricSnapshot(
            metricType: metric, unit: unitName, valueAvg: value, valueMin: nil, valueMax: nil,
            valueLatest: value, valueTotal: nil, sampleCount: 1, qualityState: "ok", hrvMethod: nil
        )
    }

    private static func mindfulness(
        _ store: HKHealthStore,
        start: Date,
        end: Date
    ) async -> HealthMetricSnapshot? {
        guard let mindfulType else {
            return unsupported("mindfulness_minutes", "min")
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples = await categorySamples(store, type: mindfulType, predicate: predicate, limit: 200)
        guard !samples.isEmpty else {
            return HealthMetricSnapshot(
                metricType: "mindfulness_minutes", unit: "min", valueAvg: nil, valueMin: nil, valueMax: nil,
                valueLatest: nil, valueTotal: nil, sampleCount: 0, qualityState: "no_records", hrvMethod: nil
            )
        }
        let totalMinutes = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60.0 }
        return HealthMetricSnapshot(
            metricType: "mindfulness_minutes", unit: "min", valueAvg: nil, valueMin: nil, valueMax: nil,
            valueLatest: nil, valueTotal: totalMinutes, sampleCount: samples.count, qualityState: "ok", hrvMethod: nil
        )
    }

    private static func workouts(
        _ store: HKHealthStore,
        start: Date,
        end: Date
    ) async -> [HealthMetricSnapshot] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: 50,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
        if workouts.isEmpty {
            return [
                HealthMetricSnapshot(
                    metricType: "workout_count", unit: "count", valueAvg: nil, valueMin: nil, valueMax: nil,
                    valueLatest: nil, valueTotal: nil, sampleCount: 0, qualityState: "no_records", hrvMethod: nil
                ),
            ]
        }
        let totalMinutes = workouts.reduce(0.0) { $0 + $1.duration / 60.0 }
        return [
            HealthMetricSnapshot(
                metricType: "workout_count", unit: "count", valueAvg: nil, valueMin: nil, valueMax: nil,
                valueLatest: nil, valueTotal: Double(workouts.count), sampleCount: workouts.count,
                qualityState: "ok", hrvMethod: nil
            ),
            HealthMetricSnapshot(
                metricType: "workout_duration", unit: "min", valueAvg: nil, valueMin: nil, valueMax: nil,
                valueLatest: nil, valueTotal: totalMinutes, sampleCount: workouts.count,
                qualityState: "ok", hrvMethod: nil
            ),
        ]
    }

    private static func sleep(
        _ store: HKHealthStore,
        dayStart: Date,
        calendar: Calendar
    ) async -> HealthSleepSnapshot? {
        guard let sleepType else {
            return HealthSleepSnapshot(
                totalMinutes: nil, inBedMinutes: nil, awakeMinutes: nil, coreLightMinutes: nil,
                deepMinutes: nil, remMinutes: nil, sleepStart: nil, sleepEnd: nil, qualityState: "unsupported"
            )
        }
        let windowStart = calendar.date(byAdding: .hour, value: -36, to: dayStart) ?? dayStart
        let windowEnd = calendar.date(byAdding: .hour, value: 12, to: dayStart) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)
        let samples = await categorySamples(store, type: sleepType, predicate: predicate, limit: 400)
        guard !samples.isEmpty else {
            return HealthSleepSnapshot(
                totalMinutes: nil, inBedMinutes: nil, awakeMinutes: nil, coreLightMinutes: nil,
                deepMinutes: nil, remMinutes: nil, sleepStart: nil, sleepEnd: nil, qualityState: "no_records"
            )
        }
        var awake = 0.0
        var coreLight = 0.0
        var deep = 0.0
        var rem = 0.0
        var inBed = 0.0
        var sleepStart: Date?
        var sleepEnd: Date?
        for sample in samples {
            let minutes = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
            let value = sample.value
            var isAsleep = false
            if value == HKCategoryValueSleepAnalysis.inBed.rawValue {
                inBed += minutes
            } else if value == HKCategoryValueSleepAnalysis.awake.rawValue {
                awake += minutes
            } else if value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue {
                deep += minutes
                isAsleep = true
            } else if value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                rem += minutes
                isAsleep = true
            } else if value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                        || value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                        || value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                coreLight += minutes
                isAsleep = true
            }
            if isAsleep {
                sleepStart = sleepStart.map { min($0, sample.startDate) } ?? sample.startDate
                sleepEnd = sleepEnd.map { max($0, sample.endDate) } ?? sample.endDate
            }
        }
        let total = coreLight + deep + rem
        let hasStages = deep > 0 || rem > 0 || coreLight > 0
        let quality = hasStages ? (deep > 0 || rem > 0 ? "ok" : "partial") : (total > 0 ? "partial" : "no_records")
        return HealthSleepSnapshot(
            totalMinutes: total > 0 ? Int(total.rounded()) : nil,
            inBedMinutes: inBed > 0 ? Int(inBed.rounded()) : nil,
            awakeMinutes: awake > 0 ? Int(awake.rounded()) : nil,
            coreLightMinutes: coreLight > 0 ? Int(coreLight.rounded()) : nil,
            deepMinutes: deep > 0 ? Int(deep.rounded()) : nil,
            remMinutes: rem > 0 ? Int(rem.rounded()) : nil,
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            qualityState: quality
        )
    }

    private static func unsupported(
        _ metric: String,
        _ unitName: String,
        hrvMethod: String? = nil
    ) -> HealthMetricSnapshot {
        HealthMetricSnapshot(
            metricType: metric, unit: unitName, valueAvg: nil, valueMin: nil, valueMax: nil,
            valueLatest: nil, valueTotal: nil, sampleCount: 0, qualityState: "unsupported", hrvMethod: hrvMethod
        )
    }

    private static func sumQuantity(
        _ store: HKHealthStore,
        type: HKQuantityType,
        unit: HKUnit,
        predicate: NSPredicate
    ) async -> Double? {
        await statistics(store, type: type, predicate: predicate, options: .cumulativeSum)?
            .sumQuantity()?
            .doubleValue(for: unit)
    }

    private static func statistics(
        _ store: HKHealthStore,
        type: HKQuantityType,
        predicate: NSPredicate,
        options: HKStatisticsOptions
    ) async -> HKStatistics? {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options
            ) { _, stats, error in
                if let error {
                    let ns = error as NSError
                    if ns.domain == "com.apple.healthkit", ns.code == 6 {
                        continuation.resume(returning: nil)
                        return
                    }
                }
                continuation.resume(returning: stats)
            }
            store.execute(query)
        }
    }

    private static func latestSample(
        _ store: HKHealthStore,
        type: HKQuantityType,
        predicate: NSPredicate
    ) async -> HKQuantitySample? {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }
            store.execute(query)
        }
    }

    private static func categorySamples(
        _ store: HKHealthStore,
        type: HKCategoryType,
        predicate: NSPredicate,
        limit: Int
    ) async -> [HKCategorySample] {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
    }
}
