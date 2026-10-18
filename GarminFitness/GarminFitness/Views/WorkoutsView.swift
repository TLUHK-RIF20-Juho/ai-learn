import Charts
import SwiftUI

struct WorkoutsView: View {
    @Environment(FitnessStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.workoutsByMonth) { group in
                    Section(Format.month(group.month)) {
                        ForEach(group.workouts) { workout in
                            NavigationLink(value: workout) {
                                WorkoutRow(workout: workout)
                            }
                        }
                    }
                }
            }
            .overlay {
                if store.workouts.isEmpty && !store.isLoading {
                    ContentUnavailableView(
                        "Treeninguid pole",
                        systemImage: "figure.run",
                        description: Text("Luba Garmin Connectis andmete jagamine Apple Healthiga.")
                    )
                }
            }
            .navigationTitle("Treeningud")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .refreshable { await store.load() }
        }
    }
}

struct WorkoutDetailView: View {
    @Environment(FitnessStore.self) private var store
    let workout: Workout

    @State private var samples: [HeartRateSample] = []
    @State private var isLoading = true

    private var averageHeartRate: Double? {
        workout.averageHeartRate ?? (samples.isEmpty ? nil : ActivityMath.average(samples.map(\.bpm)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                metrics
                heartRateCard
                if !samples.isEmpty {
                    zonesCard
                }
            }
            .padding()
        }
        .navigationTitle(workout.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            samples = await store.heartRate(for: workout)
            isLoading = false
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: workout.kind.symbol)
                .font(.largeTitle)
                .foregroundStyle(Ring.exercise.color)
                .frame(width: 64, height: 64)
                .background(Ring.exercise.color.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.kind.title).font(.title2.bold())
                Text("\(Format.time(workout.start))–\(Format.time(workout.end)) · \(Format.shortDay(workout.start))")
                    .foregroundStyle(.secondary)
                Text(workout.sourceName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 16) {
            Metric(title: "Treeningu aeg", value: Format.duration(workout.duration), color: Ring.exercise.color)
            if let distance = workout.distance, distance > 0 {
                Metric(title: "Vahemaa", value: Format.distance(distance), color: Ring.steps.color)
                if let tempo = workout.kind.usesPace
                    ? Format.pace(seconds: workout.duration, meters: distance)
                    : Format.speed(seconds: workout.duration, meters: distance) {
                    Metric(title: workout.kind.usesPace ? "Keskmine tempo" : "Keskmine kiirus", value: tempo, color: Ring.steps.color)
                }
            }
            if let energy = workout.activeEnergy {
                Metric(title: "Aktiivsed kalorid", value: "\(Format.number(energy)) kcal", color: Ring.move.color)
            }
            if let averageHeartRate {
                Metric(title: "Keskmine pulss", value: "\(Format.number(averageHeartRate)) l/min", color: Ring.move.color)
            }
        }
        .card()
    }

    @ViewBuilder
    private var heartRateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pulss").font(.headline)
            if samples.isEmpty {
                Text(isLoading ? "Laadin…" : "Pulsiandmeid pole.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let values = samples.map(\.bpm)
                let low = (values.min() ?? 60) - 10
                let high = (values.max() ?? 180) + 10
                Chart(samples) { sample in
                    LineMark(x: .value("Aeg", sample.date), y: .value("Pulss", sample.bpm))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Ring.move.color)
                }
                .chartYScale(domain: low...high)
                .frame(height: 180)
                HStack {
                    Text("Min \(Format.number(values.min() ?? 0))")
                    Spacer()
                    Text("Max \(Format.number(values.max() ?? 0)) l/min")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var zonesCard: some View {
        let zones = ActivityMath.heartRateZones(samples, maxHeartRate: store.goals.maxHeartRate)
        let total = max(zones.reduce(0, +), 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Pulsitsoonid").font(.headline)
            ForEach(zones.indices, id: \.self) { index in
                HStack {
                    Text("Tsoon \(index + 1)")
                        .font(.subheadline)
                        .frame(width: 70, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(HeartRateZone.colors[index])
                            .frame(width: max(proxy.size.width * zones[index] / total, 4))
                    }
                    .frame(height: 10)
                    Text(Format.duration(zones[index]))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 64, alignment: .trailing)
                }
            }
        }
        .card()
    }
}

private struct Metric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
