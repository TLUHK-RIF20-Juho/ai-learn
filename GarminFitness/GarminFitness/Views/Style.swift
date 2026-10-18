import SwiftUI

extension Ring {
    var color: Color {
        switch self {
        case .move: Color(red: 0.98, green: 0.07, blue: 0.31)
        case .exercise: Color(red: 0.65, green: 1.0, blue: 0.0)
        case .steps: Color(red: 0.0, green: 0.85, blue: 0.95)
        }
    }

    var symbol: String {
        switch self {
        case .move: "flame.fill"
        case .exercise: "figure.run"
        case .steps: "figure.walk"
        }
    }
}

enum HeartRateZone {
    static let colors: [Color] = [.gray, .blue, .green, .orange, .red]
}

extension View {
    func card() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

enum Format {
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)).locale(.et))
    }

    static func distance(_ meters: Double) -> String {
        if meters < 1_000 {
            return "\(number(meters)) m"
        }
        let km = (meters / 1_000).formatted(.number.precision(.fractionLength(2)).locale(.et))
        return "\(km) km"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 1)))
    }

    static func pace(seconds: TimeInterval, meters: Double) -> String? {
        guard meters > 0 else { return nil }
        let perKm = Int((seconds / (meters / 1_000)).rounded())
        return String(format: "%d:%02d /km", perKm / 60, perKm % 60)
    }

    static func speed(seconds: TimeInterval, meters: Double) -> String? {
        guard seconds > 0 else { return nil }
        let kmh = (meters / 1_000) / (seconds / 3_600)
        return "\(kmh.formatted(.number.precision(.fractionLength(1)).locale(.et))) km/h"
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.et))
    }

    static func shortDay(_ date: Date) -> String {
        if Calendar.fitness.isDateInToday(date) { return "Täna" }
        if Calendar.fitness.isDateInYesterday(date) { return "Eile" }
        return date.formatted(.dateTime.day().month(.abbreviated).locale(.et))
    }

    static func month(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year().locale(.et)).capitalized(with: .et)
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(.et))
    }
}

extension Workout {
    /// Põhinäitaja nimekirjas: vahemaa, kui see on olemas, muidu kestus.
    var headline: String {
        if let distance, distance > 0 { return Format.distance(distance) }
        return Format.duration(duration)
    }
}
