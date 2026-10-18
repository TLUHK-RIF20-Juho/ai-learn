import Foundation

/// Puhtad arvutused, mis ei sõltu HealthKitist (kaetud testidega).
enum ActivityMath {
    static func progress(_ value: Double, goal: Double) -> Double {
        goal > 0 ? max(value, 0) / goal : 0
    }

    /// Treeninguminutid antud ajavahemikus. Kattuvad treeningud loetakse üks kord
    /// ja üle päeva piiri ulatuvad treeningud lõigatakse vahemiku piiridele.
    static func exerciseMinutes(of workouts: [Workout], in interval: DateInterval) -> Double {
        let clipped = workouts.compactMap { workout -> DateInterval? in
            let start = max(workout.start, interval.start)
            let end = min(workout.end, interval.end)
            return end > start ? DateInterval(start: start, end: end) : nil
        }
        .sorted { $0.start < $1.start }

        var total: TimeInterval = 0
        var current: DateInterval?
        for part in clipped {
            if let merged = current, part.start <= merged.end {
                current = DateInterval(start: merged.start, end: max(merged.end, part.end))
            } else {
                if let merged = current { total += merged.duration }
                current = part
            }
        }
        if let merged = current { total += merged.duration }
        return total / 60
    }

    /// Mitu päeva järjest on liikumisrõngas suletud. Tänane päev loetakse
    /// seeriasse ainult siis, kui eesmärk on juba täidetud.
    static func moveStreak(days: [DailyActivity], goals: Goals, today: Date, calendar: Calendar) -> Int {
        guard goals.moveKcal > 0 else { return 0 }
        let byDay = Dictionary(days.map { (calendar.startOfDay(for: $0.date), $0) }, uniquingKeysWith: { first, _ in first })
        func closed(_ day: Date) -> Bool { (byDay[day]?.activeEnergy ?? 0) >= goals.moveKcal }

        var day = calendar.startOfDay(for: today)
        if !closed(day), let yesterday = calendar.date(byAdding: .day, value: -1, to: day) {
            day = yesterday
        }
        var count = 0
        while closed(day), let previous = calendar.date(byAdding: .day, value: -1, to: day) {
            count += 1
            day = previous
        }
        return count
    }

    /// Aeg (sekundites) viies pulsitsoonis: 50–60–70–80–90–100% maksimumpulsist.
    static func heartRateZones(_ samples: [HeartRateSample], maxHeartRate: Double) -> [TimeInterval] {
        var zones = Array(repeating: 0.0, count: 5)
        guard maxHeartRate > 0 else { return zones }
        for (sample, next) in zip(samples, samples.dropFirst()) {
            // Pikemad augud (nt kell eemal) ei lähe arvesse
            let elapsed = min(max(next.date.timeIntervalSince(sample.date), 0), 60)
            let tenths = Int((sample.bpm / maxHeartRate * 10 + 1e-9).rounded(.down))
            zones[min(max(tenths - 5, 0), 4)] += elapsed
        }
        return zones
    }

    static func average(_ values: some Collection<Double>) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}
