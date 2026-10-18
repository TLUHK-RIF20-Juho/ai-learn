import Charts
import SwiftUI

/// Ühe päeva detailvaade: rõngad, tunnipõhised graafikud ja selle päeva treeningud.
/// Noolte või külgsuunas libistamisega saab liikuda eelmisele/järgmisele päevale.
struct DayDetailView: View {
    @Environment(FitnessStore.self) private var store
    @State private var date: Date
    @State private var hourly: [HourlyActivity] = []
    @State private var isLoading = true

    init(date: Date) {
        _date = State(initialValue: Calendar.fitness.startOfDay(for: date))
    }

    var body: some View {
        let day = store.activity(on: date)
        let dayWorkouts = store.workouts(on: date)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dayPicker
                DayRingsCard(day: day, goals: store.goals)

                ForEach(Ring.allCases) { ring in
                    HourlyChartCard(ring: ring, date: date, hourly: hourly, total: day.map(ring.value(in:)) ?? 0, isLoading: isLoading)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    StatTile(
                        title: "Vahemaa",
                        value: Format.distance(day?.distance ?? 0),
                        symbol: "location.fill",
                        color: Ring.steps.color
                    )
                    StatTile(
                        title: "Puhkepulss",
                        value: day?.restingHeartRate.map { "\(Format.number($0)) l/min" } ?? "–",
                        symbol: "heart.fill",
                        color: Ring.move.color
                    )
                }

                Text("Treeningud")
                    .font(.title2.bold())
                    .padding(.top, 8)
                if dayWorkouts.isEmpty {
                    Text("Sel päeval treeninguid ei salvestatud.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .card()
                } else {
                    ForEach(dayWorkouts) { workout in
                        NavigationLink(value: workout) {
                            WorkoutRow(workout: workout)
                                .card()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(Format.shortDay(date))
        .navigationBarTitleDisplayMode(.inline)
        .simultaneousGesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
                    move(value.translation.width < 0 ? 1 : -1)
                }
        )
        .task(id: date) {
            isLoading = true
            hourly = await store.hourlyActivity(on: date)
            isLoading = false
        }
    }

    private var dayPicker: some View {
        HStack {
            Button { move(-1) } label: {
                Image(systemName: "chevron.left.circle.fill")
            }
            .disabled(store.day(-1, from: date) == nil)
            .accessibilityLabel("Eelmine päev")

            Spacer()
            Text(Format.day(date))
                .font(.headline)
                .multilineTextAlignment(.center)
            Spacer()

            Button { move(1) } label: {
                Image(systemName: "chevron.right.circle.fill")
            }
            .disabled(store.day(1, from: date) == nil)
            .accessibilityLabel("Järgmine päev")
        }
        .font(.title)
        .symbolRenderingMode(.hierarchical)
    }

    private func move(_ offset: Int) {
        guard let target = store.day(offset, from: date) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { date = target }
    }
}

/// Tunnipõhine tulpdiagramm ühe rõnga kohta (nagu Apple Fitnessi päeva vaates).
private struct HourlyChartCard: View {
    let ring: Ring
    let date: Date
    let hourly: [HourlyActivity]
    let total: Double
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(ring.title, systemImage: ring.symbol)
                    .font(.headline)
                    .foregroundStyle(ring.color)
                Spacer()
                Text("\(Format.number(total)) \(ring.unit)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(ring.color)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            if hourly.isEmpty {
                Text(isLoading ? "Laadin…" : "Andmeid pole.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(hourly) { hour in
                    BarMark(x: .value("Tund", hour.date, unit: .hour), y: .value(ring.title, ring.value(in: hour)))
                        .foregroundStyle(ring.color)
                        .cornerRadius(2)
                }
                .chartXScale(domain: date...date.addingTimeInterval(24 * 3_600))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)).locale(.et))
                    }
                }
                .frame(height: 120)
            }
        }
        .card()
    }
}
