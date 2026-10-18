import SwiftUI

struct RingView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.7), color], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            // Teine ring, kui eesmärk on ületatud (nagu Apple Fitnessis)
            if progress > 1 {
                let tip = min(progress - 1, 1)
                Circle()
                    .trim(from: 0, to: tip)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                // Vari ainult ringi otsas, langeb liikumissuunas eelmisele ringile
                Circle()
                    .fill(color)
                    .frame(width: lineWidth, height: lineWidth)
                    .shadow(color: .black.opacity(0.55), radius: lineWidth / 5, x: lineWidth / 5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .offset(y: -lineWidth / 2)
                    .rotationEffect(.degrees(360 * tip))
                // Katab otsa taha langeva varju, et see ei paistaks ringi enda peal
                Circle()
                    .trim(from: max(tip - 0.03, 0), to: tip)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(lineWidth / 2)
        .animation(.easeOut(duration: 0.8), value: progress)
    }
}

struct ActivityRingsView: View {
    let day: DailyActivity?
    let goals: Goals
    var lineWidth: CGFloat = 22
    var spacing: CGFloat = 3

    var body: some View {
        ZStack {
            ForEach(Array(Ring.allCases.enumerated()), id: \.element) { index, ring in
                RingView(
                    progress: day.map { ring.progress(in: $0, goals: goals) } ?? 0,
                    color: ring.color,
                    lineWidth: lineWidth
                )
                .padding(CGFloat(index) * (lineWidth + spacing))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let day else { return "Andmed puuduvad" }
        return Ring.allCases
            .map { "\($0.title) \(Format.number($0.value(in: day))) / \(Format.number($0.goal(in: goals))) \($0.unit)" }
            .joined(separator: ", ")
    }
}

#Preview {
    ActivityRingsView(
        day: DailyActivity(date: .now, activeEnergy: 620, exerciseMinutes: 18, steps: 7_400, distance: 5_200, restingHeartRate: 54),
        goals: Goals()
    )
    .frame(width: 220)
    .padding()
    .preferredColorScheme(.dark)
}
