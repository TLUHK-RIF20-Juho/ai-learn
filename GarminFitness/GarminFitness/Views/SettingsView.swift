import SwiftUI

struct SettingsView: View {
    @Environment(FitnessStore.self) private var store

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            Form {
                Section("Päevased eesmärgid") {
                    Stepper(value: $store.goals.moveKcal, in: 100...2_000, step: 10) {
                        LabeledContent(Ring.move.title, value: "\(Format.number(store.goals.moveKcal)) kcal")
                    }
                    Stepper(value: $store.goals.exerciseMinutes, in: 5...240, step: 5) {
                        LabeledContent(Ring.exercise.title, value: "\(Format.number(store.goals.exerciseMinutes)) min")
                    }
                    Stepper(value: $store.goals.steps, in: 1_000...40_000, step: 500) {
                        LabeledContent(Ring.steps.title, value: Format.number(store.goals.steps))
                    }
                }

                Section {
                    Stepper(value: $store.goals.maxHeartRate, in: 120...220) {
                        LabeledContent("Maksimaalne pulss", value: "\(Format.number(store.goals.maxHeartRate)) l/min")
                    }
                } header: {
                    Text("Pulsitsoonid")
                } footer: {
                    Text("Tsoonid on 50–60–70–80–90–100% maksimaalsest pulsist, nagu Garmin Connecti vaikeseadetes.")
                }

                Section {
                    Toggle("Näidisandmed", isOn: $store.useDemoData)
                    Button("Värskenda andmeid") {
                        Task { await store.load() }
                    }
                    .disabled(store.isLoading)
                } header: {
                    Text("Andmeallikas")
                } footer: {
                    if let updated = store.lastUpdated {
                        Text("Viimati uuendatud \(Format.time(updated)).")
                    }
                }

                Section {
                    Label("Ava telefonis Garmin Connect.", systemImage: "1.circle")
                    Label("Vali Rohkem → Seaded → Ühendatud rakendused → Apple Health.", systemImage: "2.circle")
                    Label("Luba kõik andmetüübid (sammud, kalorid, treeningud, pulss).", systemImage: "3.circle")
                    Label("Tervise rakenduses: Profiil → Rakendused → Treening → luba lugemine.", systemImage: "4.circle")
                    if let url = URL(string: "x-apple-health://") {
                        Link("Ava rakendus Tervis", destination: url)
                    }
                } header: {
                    Text("Garmini kella ühendamine")
                } footer: {
                    Text("Garmin Connect sünkroniseerib kella andmed Apple Healthi, kust see rakendus neid loeb. Seismise tunde Garmin Apple Healthi ei kirjuta, seepärast on kolmas rõngas sammud.")
                }
            }
            .navigationTitle("Seaded")
        }
    }
}
