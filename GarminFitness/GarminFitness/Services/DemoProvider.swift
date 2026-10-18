import Foundation

/// Näidisandmed simulaatori ja eelvaadete jaoks. Andmed on iga päeva kohta
/// deterministlikud, nii et värskendamine ei muuda ajalugu.
struct DemoProvider: HealthDataProvider {
    let calendar: Calendar
    var now: Date = .now

    func requestAuthorization() async throws {}

    func dailyActivity(from start: Date, to end: Date) async throws -> [DailyActivity] {
        days(from: start, to: end).map(activity(on:))
    }

    func hourlyActivity(on day: Date) async throws -> [HourlyActivity] {
        let dayStart = calendar.startOfDay(for: day)
        let total = activity(on: dayStart)
        let finished = finishedWorkouts(on: dayStart)
        var rng = SeededGenerator(seed: seed(for: dayStart) ^ 0x5A5A)

        let hours: [DateInterval] = (0..<24).compactMap { offset in
            guard let start = calendar.date(byAdding: .hour, value: offset, to: dayStart), start <= now,
                  let end = calendar.date(byAdding: .hour, value: 1, to: start) else { return nil }
            return DateInterval(start: start, end: end)
        }
        guard !hours.isEmpty else { return [] }

        // Päevane taustaliikumine jaotatakse tundidele: öösel vähe, päeval rohkem
        let weights = hours.map { interval -> Double in
            let hour = calendar.component(.hour, from: interval.start)
            switch hour {
            case 7..<22: return Double.random(in: 0.4...1.6, using: &rng)
            case 6, 22: return 0.2
            default: return 0.02
            }
        }
        let weightSum = weights.reduce(0, +)

        let workoutEnergy = finished.compactMap(\.activeEnergy).reduce(0, +)
        let workoutSteps = finished.map(steps(in:)).reduce(0, +)
        let workoutMinutes = ActivityMath.exerciseMinutes(of: finished, in: DateInterval(start: dayStart, end: hours.last?.end ?? dayStart))
        let baseEnergy = max(total.activeEnergy - workoutEnergy, 0)
        let baseSteps = max(total.steps - workoutSteps, 0)
        let baseMinutes = max(total.exerciseMinutes - workoutMinutes, 0)

        return zip(hours, weights).map { interval, weight in
            let share = weight / weightSum
            // Treeningu osa, mis jääb sellesse tundi
            let overlap = finished.map { workout -> Double in
                let start = max(workout.start, interval.start), end = min(workout.end, interval.end)
                return end > start ? end.timeIntervalSince(start) / workout.duration : 0
            }
            let hourWorkoutEnergy = zip(finished, overlap).map { ($0.activeEnergy ?? 0) * $1 }.reduce(0, +)
            let hourWorkoutSteps = zip(finished, overlap).map { self.steps(in: $0) * $1 }.reduce(0, +)
            return HourlyActivity(
                date: interval.start,
                activeEnergy: (baseEnergy * share + hourWorkoutEnergy).rounded(),
                exerciseMinutes: (baseMinutes * share + ActivityMath.exerciseMinutes(of: finished, in: interval)).rounded(),
                steps: (baseSteps * share + hourWorkoutSteps).rounded()
            )
        }
    }

    func workouts(from start: Date, to end: Date) async throws -> [Workout] {
        days(from: start, to: end)
            .compactMap(workout(on:))
            .filter { $0.start >= start && $0.end <= min(end, now) }
            .reversed()
    }

    func heartRate(for workout: Workout) async throws -> [HeartRateSample] {
        var rng = SeededGenerator(seed: seed(for: workout.start) &+ 7)
        let target = (workout.averageHeartRate ?? 130) + 4
        var samples: [HeartRateSample] = []
        var elapsed: TimeInterval = 0
        while elapsed <= workout.duration {
            let warmup = min(1, elapsed / 300)
            let bpm = 75 + (target - 75) * warmup + sin(elapsed / 240) * 8 + Double.random(in: -3...3, using: &rng)
            samples.append(HeartRateSample(date: workout.start.addingTimeInterval(elapsed), bpm: bpm.rounded()))
            elapsed += 10
        }
        return samples
    }

    // MARK: - Genereerimine

    private func days(from start: Date, to end: Date) -> [Date] {
        var result: [Date] = []
        var day = calendar.startOfDay(for: start)
        while day < end, day <= now, let next = calendar.date(byAdding: .day, value: 1, to: day) {
            result.append(day)
            day = next
        }
        return result
    }

    private func dayNumber(_ date: Date) -> Int {
        calendar.dateComponents([.day], from: Date(timeIntervalSinceReferenceDate: 0), to: calendar.startOfDay(for: date)).day ?? 0
    }

    private func seed(for date: Date) -> UInt64 {
        UInt64(truncatingIfNeeded: dayNumber(date)) &* 0x2545_F491_4F6C_DD1D
    }

    func workout(on day: Date) -> Workout? {
        var rng = SeededGenerator(seed: seed(for: day))
        guard Double.random(in: 0...1, using: &rng) < 0.6 else { return nil }

        let kinds: [WorkoutKind] = [.running, .running, .walking, .cycling, .strength, .hiking, .swimming, .yoga]
        let kind = kinds.randomElement(using: &rng) ?? .running
        let minutes = Double.random(in: 25...75, using: &rng)
        let hour = Bool.random(using: &rng) ? 7 : 18
        let minute = Int.random(in: 0...45, using: &rng)
        guard let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { return nil }

        let profile = Self.profile(for: kind)
        return Workout(
            id: "demo-\(dayNumber(day))",
            kind: kind,
            start: start,
            end: start.addingTimeInterval(minutes * 60),
            activeEnergy: (minutes * profile.kcalPerMinute * Double.random(in: 0.9...1.1, using: &rng)).rounded(),
            distance: profile.metersPerMinute.map { (minutes * $0 * Double.random(in: 0.9...1.1, using: &rng)).rounded() },
            averageHeartRate: (profile.heartRate + Double.random(in: -6...6, using: &rng)).rounded(),
            sourceName: "Garmin Connect (näidis)"
        )
    }

    func activity(on day: Date) -> DailyActivity {
        var rng = SeededGenerator(seed: seed(for: day) ^ 0xA5A5)
        let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        // Tänane päev on alles pooleli
        let fraction = now < next ? min(max(now.timeIntervalSince(day) / 86_400, 0), 1) : 1

        let finished = finishedWorkouts(on: day)
        let workoutEnergy = finished.compactMap(\.activeEnergy).reduce(0, +)
        let workoutSteps = finished.map(steps(in:)).reduce(0, +)

        let steps = (Double.random(in: 3_500...9_000, using: &rng) * fraction + workoutSteps).rounded()
        return DailyActivity(
            date: day,
            activeEnergy: (Double.random(in: 180...380, using: &rng) * fraction + workoutEnergy).rounded(),
            exerciseMinutes: (ActivityMath.exerciseMinutes(of: finished, in: DateInterval(start: day, end: next))
                + Double.random(in: 0...12, using: &rng) * fraction).rounded(),
            steps: steps,
            distance: (steps * 0.75).rounded(),
            restingHeartRate: Double.random(in: 51...58, using: &rng).rounded()
        )
    }

    private func finishedWorkouts(on day: Date) -> [Workout] {
        [workout(on: day)].compactMap { $0 }.filter { $0.end <= now }
    }

    /// Sammud jooksu-, kõnni- ja matkatreeningul (~0,8 m sammu kohta).
    private func steps(in workout: Workout) -> Double {
        workout.kind.usesPace ? (workout.distance ?? 0) / 0.8 : 0
    }

    private static func profile(for kind: WorkoutKind) -> (kcalPerMinute: Double, metersPerMinute: Double?, heartRate: Double) {
        switch kind {
        case .running: return (13, 170, 152)
        case .walking: return (5, 90, 108)
        case .cycling: return (10, 450, 138)
        case .swimming: return (9, 40, 135)
        case .strength: return (7, nil, 118)
        case .hiking: return (7, 70, 122)
        case .yoga: return (3.5, nil, 95)
        case .other: return (6, nil, 115)
        }
    }
}

/// SplitMix64 – lihtne korratav juhuarvugeneraator.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
