import Foundation
import Observation

@MainActor
@Observable
final class FitnessStore {
    static let historyDays = 35
    static let workoutHistoryDays = 90

    var goals: Goals {
        didSet { save(goals) }
    }

    var useDemoData: Bool {
        didSet {
            defaults.set(useDemoData, forKey: Keys.demo)
            Task { await load() }
        }
    }

    private(set) var days: [DailyActivity] = []
    private(set) var workouts: [Workout] = []
    private(set) var isLoading = false
    private(set) var lastUpdated: Date?
    var errorMessage: String?

    let calendar: Calendar = .fitness
    private let defaults: UserDefaults
    private let healthKit: HealthKitProvider

    private enum Keys {
        static let goals = "goals"
        static let demo = "useDemoData"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        healthKit = HealthKitProvider(calendar: .fitness)

        if let data = defaults.data(forKey: Keys.goals), let saved = try? JSONDecoder().decode(Goals.self, from: data) {
            goals = saved
        } else {
            goals = Goals()
        }

        if defaults.object(forKey: Keys.demo) != nil {
            useDemoData = defaults.bool(forKey: Keys.demo)
        } else {
            #if targetEnvironment(simulator)
            useDemoData = true
            #else
            useDemoData = !HealthKitProvider.isAvailable
            #endif
        }
    }

    private var provider: any HealthDataProvider {
        useDemoData ? DemoProvider(calendar: calendar) : healthKit
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let provider = self.provider
        let today = calendar.startOfDay(for: .now)
        guard
            let end = calendar.date(byAdding: .day, value: 1, to: today),
            let start = calendar.date(byAdding: .day, value: -(Self.historyDays - 1), to: today),
            let workoutStart = calendar.date(byAdding: .day, value: -Self.workoutHistoryDays, to: today)
        else { return }

        do {
            try await provider.requestAuthorization()
            async let loadedDays = provider.dailyActivity(from: start, to: end)
            async let loadedWorkouts = provider.workouts(from: workoutStart, to: end)
            days = try await loadedDays
            workouts = try await loadedWorkouts
            lastUpdated = .now
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func hourlyActivity(on date: Date) async -> [HourlyActivity] {
        (try? await provider.hourlyActivity(on: date)) ?? []
    }

    func workouts(on date: Date) -> [Workout] {
        workouts.filter { calendar.isDate($0.start, inSameDayAs: date) }.reversed()
    }

    /// Eelmine/järgmine päev laaditud ajaloo piires (tulevikku ei lähe).
    func day(_ offset: Int, from date: Date) -> Date? {
        guard let target = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date)),
              let first = days.first?.date,
              target >= first, target <= .now
        else { return nil }
        return target
    }

    func heartRate(for workout: Workout) async -> [HeartRateSample] {
        (try? await provider.heartRate(for: workout)) ?? []
    }

    // MARK: - Tuletatud andmed

    var today: DailyActivity? { activity(on: .now) }

    func activity(on date: Date) -> DailyActivity? {
        days.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    var currentWeek: [WeekDay] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: week.start).map { WeekDay(date: $0, activity: activity(on: $0)) }
        }
    }

    var workoutsThisWeek: [Workout] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return workouts.filter { week.contains($0.start) }
    }

    var moveStreak: Int {
        ActivityMath.moveStreak(days: days, goals: goals, today: .now, calendar: calendar)
    }

    var workoutsByMonth: [MonthGroup] {
        let grouped = Dictionary(grouping: workouts) {
            calendar.dateInterval(of: .month, for: $0.start)?.start ?? $0.start
        }
        return grouped.keys.sorted(by: >).map { MonthGroup(month: $0, workouts: grouped[$0] ?? []) }
    }

    /// Viimase 7 lõpetatud päeva keskmine võrreldes eelneva 28 päevaga.
    func trend(for ring: Ring) -> Trend {
        let finished = days.filter { !calendar.isDateInToday($0.date) }
        let recent = finished.suffix(7).map(ring.value(in:))
        let previous = finished.dropLast(7).suffix(28).map(ring.value(in:))
        return Trend(recent: ActivityMath.average(recent), previous: ActivityMath.average(previous))
    }

    private func save(_ goals: Goals) {
        if let data = try? JSONEncoder().encode(goals) {
            defaults.set(data, forKey: Keys.goals)
        }
    }
}
