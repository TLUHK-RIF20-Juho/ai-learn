import XCTest
@testable import GarminFitness

final class ActivityMathTests: XCTestCase {
    private let calendar = Calendar.fitness

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func workout(_ start: Date, minutes: Double) -> Workout {
        Workout(id: UUID().uuidString, kind: .running, start: start, end: start.addingTimeInterval(minutes * 60),
                activeEnergy: nil, distance: nil, averageHeartRate: nil, sourceName: "test")
    }

    func testOverlappingWorkoutsAreCountedOnce() {
        let day = DateInterval(start: date(14, 0), end: date(15, 0))
        let workouts = [workout(date(14, 7), minutes: 60), workout(date(14, 7, 30), minutes: 60), workout(date(14, 18), minutes: 15)]
        XCTAssertEqual(ActivityMath.exerciseMinutes(of: workouts, in: day), 105, accuracy: 0.001)
    }

    func testWorkoutIsClippedToDay() {
        let day = DateInterval(start: date(14, 0), end: date(15, 0))
        let workouts = [workout(date(14, 23, 30), minutes: 60)]
        XCTAssertEqual(ActivityMath.exerciseMinutes(of: workouts, in: day), 30, accuracy: 0.001)
    }

    func testStreakIgnoresUnfinishedToday() {
        let goals = Goals(moveKcal: 500)
        let days = [
            DailyActivity(date: date(12, 0), activeEnergy: 300, exerciseMinutes: 0, steps: 0, distance: 0, restingHeartRate: nil),
            DailyActivity(date: date(13, 0), activeEnergy: 520, exerciseMinutes: 0, steps: 0, distance: 0, restingHeartRate: nil),
            DailyActivity(date: date(14, 0), activeEnergy: 610, exerciseMinutes: 0, steps: 0, distance: 0, restingHeartRate: nil),
            DailyActivity(date: date(15, 0), activeEnergy: 120, exerciseMinutes: 0, steps: 0, distance: 0, restingHeartRate: nil),
        ]
        XCTAssertEqual(ActivityMath.moveStreak(days: days, goals: goals, today: date(15, 10), calendar: calendar), 2)

        var closedToday = days
        closedToday[3].activeEnergy = 700
        XCTAssertEqual(ActivityMath.moveStreak(days: closedToday, goals: goals, today: date(15, 20), calendar: calendar), 3)
    }

    func testHeartRateZones() {
        let start = date(14, 7)
        let samples = [100.0, 125, 145, 165, 185, 185].enumerated().map { index, bpm in
            HeartRateSample(date: start.addingTimeInterval(Double(index) * 10), bpm: bpm)
        }
        // Max 200: 100 → tsoon 1, 125 → 2, 145 → 3, 165 → 4, 185 → 5; viimasel proovil kestust pole
        XCTAssertEqual(ActivityMath.heartRateZones(samples, maxHeartRate: 200), [10, 10, 10, 10, 10])
    }

    func testProgressHandlesZeroGoal() {
        XCTAssertEqual(ActivityMath.progress(300, goal: 0), 0)
        XCTAssertEqual(ActivityMath.progress(750, goal: 500), 1.5, accuracy: 0.001)
    }

    func testDemoDataIsDeterministic() async throws {
        let now = date(18, 12)
        let provider = DemoProvider(calendar: calendar, now: now)
        let first = try await provider.dailyActivity(from: date(1, 0), to: date(19, 0))
        let second = try await provider.dailyActivity(from: date(1, 0), to: date(19, 0))
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 18)

        let workouts = try await provider.workouts(from: date(1, 0), to: date(19, 0))
        XCTAssertEqual(workouts.map(\.start), workouts.map(\.start).sorted(by: >), "uuemad treeningud eespool")
        XCTAssertTrue(workouts.allSatisfy { $0.end <= now })
    }
}
