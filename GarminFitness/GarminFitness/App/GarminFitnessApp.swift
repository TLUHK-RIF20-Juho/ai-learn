import SwiftUI

@main
struct GarminFitnessApp: App {
    @State private var store = FitnessStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(\.locale, .et)
                .task { await store.load() }
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            SummaryView()
                .tabItem { Label("Kokkuvõte", systemImage: "circle.circle") }
            WorkoutsView()
                .tabItem { Label("Treeningud", systemImage: "figure.run") }
            TrendsView()
                .tabItem { Label("Trendid", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView()
                .tabItem { Label("Seaded", systemImage: "gearshape") }
        }
        .tint(Ring.exercise.color)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    let store = FitnessStore()
    store.useDemoData = true
    return ContentView()
        .environment(store)
        .environment(\.locale, .et)
}
