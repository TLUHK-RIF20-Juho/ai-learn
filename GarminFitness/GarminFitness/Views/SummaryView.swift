import SwiftUI

struct SummaryView: View {
    @Environment(FitnessStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(Format.day(.now).uppercased())
                        .font(.footnote.bold())
                        .foregroundStyle(.secondary)

                    if let message = store.errorMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .card()
                    }

                    activityCard
                    WeekStripView(week: store.currentWeek, goals: store.goals)
                    statsGrid
                    recentWorkouts
                }
                .padding()
            }
            .navigationTitle("Kokkuvõte")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .refreshable { await store.load() }
            .overlay {
                if store.isLoading && store.days.isEmpty {
                    ProgressView()
                }
            }
        }
    }

    private var activityCard: some View {
        VStack(spacing: 20) {
            ActivityRingsView(day: store.today, goals: store.goals, lineWidth: 24)
                .frame(maxWidth: 230)
                .frame(maxWidth: .infinity)

            VStack(spacing: 14) {
                ForEach(Ring.allCases) { ring in
                    RingStatRow(ring: ring, value: store.today.map(ring.value(in:)) ?? 0, goal: ring.goal(in: store.goals))
                    if ring != Ring.allCases.last {
                        Divider()
                    }
                }
            }
        }
        .card()
    }

    private var statsGrid: some View {
        // Suure teksti korral üks veerg, et numbrid ei murduks
        let columnCount = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount), spacing: 12) {
            StatTile(
                title: "Vahemaa",
                value: Format.distance(store.today?.distance ?? 0),
                symbol: "location.fill",
                color: Ring.steps.color
            )
            StatTile(
                title: "Puhkepulss",
                value: store.today?.restingHeartRate.map { "\(Format.number($0)) l/min" } ?? "–",
                symbol: "heart.fill",
                color: Ring.move.color
            )
            StatTile(
                title: "Liikumisseeria",
                value: "\(store.moveStreak) päeva",
                symbol: "flame.fill",
                color: .orange
            )
            StatTile(
                title: "Treeninguid nädalas",
                value: "\(store.workoutsThisWeek.count)",
                symbol: "figure.run",
                color: Ring.exercise.color
            )
        }
    }

    @ViewBuilder
    private var recentWorkouts: some View {
        Text("Treeningud")
            .font(.title2.bold())
            .padding(.top, 8)

        if store.workouts.isEmpty {
            Text("Treeninguid veel pole. Salvesta treening Garmini kellaga ja sünkroniseeri Garmin Connect.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .card()
        } else {
            ForEach(store.workouts.prefix(3)) { workout in
                NavigationLink(value: workout) {
                    WorkoutRow(workout: workout)
                        .card()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Üks rida rõngaste all: ikoon ja nimi vasakul, väärtus/eesmärk paremal.
struct RingStatRow: View {
    let ring: Ring
    let value: Double
    let goal: Double

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                title
                Spacer(minLength: 8)
                amount
            }
            VStack(alignment: .leading, spacing: 2) {
                title
                amount
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: some View {
        Label(ring.title, systemImage: ring.symbol)
            .font(.headline)
            .foregroundStyle(ring.color)
            .lineLimit(1)
    }

    private var amount: some View {
        (Text(Format.number(value))
            .font(.title2.bold().monospacedDigit())
            .foregroundStyle(ring.color)
        + Text(" / \(Format.number(goal)) \(ring.unit)")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .card()
    }
}

struct WeekStripView: View {
    let week: [WeekDay]
    let goals: Goals

    var body: some View {
        HStack(spacing: 0) {
            ForEach(week) { item in
                let isToday = Calendar.fitness.isDateInToday(item.date)
                VStack(spacing: 6) {
                    Text(item.date.formatted(.dateTime.weekday(.narrow).locale(.et)))
                        .font(.caption2.bold())
                        .foregroundStyle(isToday ? Color.primary : Color.secondary)
                    ActivityRingsView(day: item.activity, goals: goals, lineWidth: 4, spacing: 1)
                        .frame(width: 36, height: 36)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .card()
    }
}

struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workout.kind.symbol)
                .font(.title2)
                .foregroundStyle(Ring.exercise.color)
                .frame(width: 48, height: 48)
                .background(Ring.exercise.color.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.kind.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(workout.headline)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(Ring.exercise.color)
            }
            Spacer()
            Text(Format.shortDay(workout.start))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}
