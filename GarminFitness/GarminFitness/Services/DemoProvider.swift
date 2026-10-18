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

        let finished = [workout(on: day)].compactMap { $0 }.filter { $0.end <= now }
        let workoutEnergy = finished.compactMap(\.activeEnergy).reduce(0, +)
        let workoutSteps = finished.filter { $0.kind.usesPace }.compactMap(\.distance).reduce(0, +) / 0.8

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
