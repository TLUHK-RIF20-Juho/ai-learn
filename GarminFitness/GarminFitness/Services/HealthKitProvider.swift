import Foundation
import HealthKit

/// Loeb andmed Apple Healthist. Garmin Connect kirjutab sinna sammud, aktiivsed kalorid,
/// treeningud ja pulsi, kui Garmin Connectis on Apple Health ühendatud.
final class HealthKitProvider: HealthDataProvider, @unchecked Sendable {
    private let store = HKHealthStore()
    private let calendar: Calendar

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.appleExerciseTime),
            HKObjectType.workoutType(),
        ]
    }

    func requestAuthorization() async throws {
        guard Self.isAvailable else { throw HealthDataError.unavailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func dailyActivity(from start: Date, to end: Date) async throws -> [DailyActivity] {
        async let energy = dailyValues(.activeEnergyBurned, unit: .kilocalorie(), options: .cumulativeSum, from: start, to: end)
        async let steps = dailyValues(.stepCount, unit: .count(), options: .cumulativeSum, from: start, to: end)
        async let distance = dailyValues(.distanceWalkingRunning, unit: .meter(), options: .cumulativeSum, from: start, to: end)
        async let exercise = dailyValues(.appleExerciseTime, unit: .minute(), options: .cumulativeSum, from: start, to: end)
        async let resting = dailyValues(.restingHeartRate, unit: .bpm, options: .discreteAverage, from: start, to: end)
        async let workoutList = workouts(from: start, to: end)

        let (energyByDay, stepsByDay, distanceByDay, exerciseByDay, restingByDay) = await (energy, steps, distance, exercise, resting)
        let allWorkouts = try await workoutList

        var result: [DailyActivity] = []
        var day = calendar.startOfDay(for: start)
        while day < end, let next = calendar.date(byAdding: .day, value: 1, to: day) {
            // Apple Watchi treeninguminuteid Garmin ei kirjuta, seega arvutame need treeningutest
            let workoutMinutes = ActivityMath.exerciseMinutes(of: allWorkouts, in: DateInterval(start: day, end: next))
            result.append(DailyActivity(
                date: day,
                activeEnergy: energyByDay[day] ?? 0,
                exerciseMinutes: max(exerciseByDay[day] ?? 0, workoutMinutes),
                steps: stepsByDay[day] ?? 0,
                distance: distanceByDay[day] ?? 0,
                restingHeartRate: restingByDay[day]
            ))
            day = next
        }
        return result
    }

    func workouts(from start: Date, to end: Date) async throws -> [Workout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try await descriptor.result(for: store).map(Self.makeWorkout)
    }

    func heartRate(for workout: Workout) async throws -> [HeartRateSample] {
        let predicate = HKQuery.predicateForSamples(withStart: workout.start, end: workout.end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.heartRate), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await descriptor.result(for: store).map {
            HeartRateSample(date: $0.startDate, bpm: $0.quantity.doubleValue(for: .bpm))
        }
    }

    /// Päevased summad/keskmised. Kui andmetüübile pole luba või andmeid, tagastab tühja sõnastiku.
    private func dailyValues(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        options: HKStatisticsOptions,
        from start: Date,
        to end: Date
    ) async -> [Date: Double] {
        let anchor = calendar.startOfDay(for: start)
        let type = HKQuantityType(identifier)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: anchor, end: end)),
            options: options,
            anchorDate: anchor,
            intervalComponents: DateComponents(day: 1)
        )
        guard let collection = try? await descriptor.result(for: store) else { return [:] }

        var values: [Date: Double] = [:]
        collection.enumerateStatistics(from: anchor, to: end) { statistics, _ in
            let quantity = options.contains(.cumulativeSum) ? statistics.sumQuantity() : statistics.averageQuantity()
            if let quantity {
                values[self.calendar.startOfDay(for: statistics.startDate)] = quantity.doubleValue(for: unit)
            }
        }
        return values
    }

    private static func makeWorkout(_ workout: HKWorkout) -> Workout {
        let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
            ?? workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())

        let distanceTypes: [HKQuantityTypeIdentifier] = [.distanceWalkingRunning, .distanceCycling, .distanceSwimming]
        let distance = distanceTypes.lazy
            .compactMap { workout.statistics(for: HKQuantityType($0))?.sumQuantity()?.doubleValue(for: .meter()) }
            .first
            ?? workout.totalDistance?.doubleValue(for: .meter())

        let heartRate = workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: .bpm)

        return Workout(
            id: workout.uuid.uuidString,
            kind: WorkoutKind(workout.workoutActivityType),
            start: workout.startDate,
            end: workout.endDate,
            activeEnergy: energy,
            distance: distance,
            averageHeartRate: heartRate,
            sourceName: workout.sourceRevision.source.name
        )
    }
}

extension HKUnit {
    static let bpm = HKUnit.count().unitDivided(by: .minute())
}

extension WorkoutKind {
    init(_ type: HKWorkoutActivityType) {
        switch type {
        case .running: self = .running
        case .walking: self = .walking
        case .cycling: self = .cycling
        case .swimming: self = .swimming
        case .traditionalStrengthTraining, .functionalStrengthTraining: self = .strength
        case .hiking: self = .hiking
        case .yoga: self = .yoga
        default: self = .other
        }
    }
}
