import Foundation

/// Ühe päeva kokkuvõte (päeva algus kohalikus ajavööndis).
struct DailyActivity: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    var activeEnergy: Double      // kcal
    var exerciseMinutes: Double   // min
    var steps: Double
    var distance: Double          // meetrid (kõnd + jooks)
    var restingHeartRate: Double? // lööki/min
}

/// Ühe tunni aktiivsus päeva detailvaate graafikute jaoks.
struct HourlyActivity: Identifiable, Hashable {
    var id: Date { date }
    let date: Date               // tunni algus
    var activeEnergy: Double     // kcal
    var exerciseMinutes: Double  // min
    var steps: Double
}

/// Navigeerimine päeva detailvaatesse.
struct DayRoute: Hashable {
    let date: Date
}

struct Goals: Codable, Equatable {
    var moveKcal: Double = 500
    var exerciseMinutes: Double = 30
    var steps: Double = 10_000
    var maxHeartRate: Double = 190
}

/// Aktiivsusrõngad. Garmin ei kirjuta Apple Healthi Apple Watchi
/// "Seismise" tunde, seega kolmas rõngas on sammud.
enum Ring: String, CaseIterable, Identifiable {
    case move, exercise, steps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .move: "Liikumine"
        case .exercise: "Treening"
        case .steps: "Sammud"
        }
    }

    var unit: String {
        switch self {
        case .move: "kcal"
        case .exercise: "min"
        case .steps: "sammu"
        }
    }

    func value(in day: DailyActivity) -> Double {
        switch self {
        case .move: day.activeEnergy
        case .exercise: day.exerciseMinutes
        case .steps: day.steps
        }
    }

    func value(in hour: HourlyActivity) -> Double {
        switch self {
        case .move: hour.activeEnergy
        case .exercise: hour.exerciseMinutes
        case .steps: hour.steps
        }
    }

    func goal(in goals: Goals) -> Double {
        switch self {
        case .move: goals.moveKcal
        case .exercise: goals.exerciseMinutes
        case .steps: goals.steps
        }
    }

    func progress(in day: DailyActivity, goals: Goals) -> Double {
        ActivityMath.progress(value(in: day), goal: goal(in: goals))
    }
}

enum WorkoutKind: String, CaseIterable, Codable {
    case running, walking, cycling, swimming, strength, hiking, yoga, other

    var title: String {
        switch self {
        case .running: "Jooks"
        case .walking: "Kõnd"
        case .cycling: "Rattasõit"
        case .swimming: "Ujumine"
        case .strength: "Jõutreening"
        case .hiking: "Matkamine"
        case .yoga: "Jooga"
        case .other: "Treening"
        }
    }

    var symbol: String {
        switch self {
        case .running: "figure.run"
        case .walking: "figure.walk"
        case .cycling: "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .strength: "figure.strengthtraining.traditional"
        case .hiking: "figure.hiking"
        case .yoga: "figure.yoga"
        case .other: "figure.mixed.cardio"
        }
    }

    /// Kas tempot on mõistlik näidata min/km (muidu km/h).
    var usesPace: Bool { [.running, .walking, .hiking].contains(self) }
}

struct Workout: Identifiable, Hashable {
    let id: String
    let kind: WorkoutKind
    let start: Date
    let end: Date
    let activeEnergy: Double?      // kcal
    let distance: Double?          // meetrid
    let averageHeartRate: Double?  // lööki/min
    let sourceName: String

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

struct HeartRateSample: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let bpm: Double
}

struct WeekDay: Identifiable {
    var id: Date { date }
    let date: Date
    let activity: DailyActivity?
}

struct MonthGroup: Identifiable {
    var id: Date { month }
    let month: Date
    let workouts: [Workout]
}

struct Trend {
    let recent: Double    // viimase 7 päeva keskmine
    let previous: Double  // eelneva 28 päeva keskmine

    var isUp: Bool { recent >= previous }
}

extension Locale {
    static let et = Locale(identifier: "et_EE")
}

extension Calendar {
    /// Eesti kalender: nädal algab esmaspäeval.
    static let fitness: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .et
        calendar.firstWeekday = 2
        return calendar
    }()
}
