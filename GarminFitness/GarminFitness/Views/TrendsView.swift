import Charts
import SwiftUI

struct TrendsView: View {
    @Environment(FitnessStore.self) private var store
    @State private var ring: Ring = .move

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Näitaja", selection: $ring) {
                        ForEach(Ring.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    chartCard

                    Text("Viimased 7 päeva vs eelnevad 28")
                        .font(.headline)
                        .padding(.top, 8)
                    ForEach(Ring.allCases) { ring in
                        TrendRow(ring: ring, trend: store.trend(for: ring))
                    }
                }
                .padding()
            }
            .navigationTitle("Trendid")
            .refreshable { await store.load() }
        }
    }

    private var chartCard: some View {
        let goal = ring.goal(in: store.goals)
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(ring.title) · 28 päeva")
                .font(.headline)
            Chart {
                ForEach(store.days.suffix(28)) { day in
                    let value = ring.value(in: day)
                    BarMark(x: .value("Päev", day.date, unit: .day), y: .value(ring.title, value))
                        .foregroundStyle(value >= goal ? ring.color : ring.color.opacity(0.45))
                        .cornerRadius(3)
                }
                RuleMark(y: .value("Eesmärk", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Eesmärk \(Format.number(goal)) \(ring.unit)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(.et))
                }
            }
            .frame(height: 220)
        }
        .card()
    }
}

private struct TrendRow: View {
    let ring: Ring
    let trend: Trend

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: trend.isUp ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(trend.isUp ? ring.color : .gray)
            VStack(alignment: .leading, spacing: 2) {
                Text(ring.title)
                    .font(.subheadline.weight(.semibold))
                Text("\(Format.number(trend.recent)) \(ring.unit)/päevas")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(ring.color)
                Text("Varem keskmiselt \(Format.number(trend.previous)) \(ring.unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}
