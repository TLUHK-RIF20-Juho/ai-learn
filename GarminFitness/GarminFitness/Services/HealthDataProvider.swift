import Foundation

/// Andmeallikas. Päris rakenduses HealthKit (kuhu Garmin Connect andmed sünkroniseerib),
/// simulaatoris ja eelvaadetes näidisandmed.
protocol HealthDataProvider: Sendable {
    func requestAuthorization() async throws
    func dailyActivity(from start: Date, to end: Date) async throws -> [DailyActivity]
    /// Antud päeva 24 tunni andmed (tänase päeva puhul kuni praeguse tunnini).
    func hourlyActivity(on day: Date) async throws -> [HourlyActivity]
    /// Treeningud uuemast vanemani.
    func workouts(from start: Date, to end: Date) async throws -> [Workout]
    func heartRate(for workout: Workout) async throws -> [HeartRateSample]
}

enum HealthDataError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable: "Tervise andmed pole selles seadmes saadaval. Lülita seadetes sisse näidisandmed."
        }
    }
}
