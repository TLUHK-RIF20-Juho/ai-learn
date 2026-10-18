import SwiftUI

struct SummaryView: View {
    @Environment(FitnessStore.self) private var store

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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Ring.allCases) { ring in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ring.title)
                            .font(.subheadline.weight(.semibold))
                        Text("\(Format.number(store.today.map(ring.value(in:)) ?? 0))/\(Format.number(ring.goal(in: store.goals))) \(ring.unit)")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(ring.color)
                    }
                }
            }
            Spacer(minLength: 0)
            ActivityRingsView(day: store.today, goals: store.goals, lineWidth: 18)
                .frame(width: 150)
        }
        .card()
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
