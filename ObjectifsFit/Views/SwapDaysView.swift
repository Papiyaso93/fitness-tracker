import SwiftUI
import SwiftData

/// Échange en un seul geste toutes les séances de deux jours d'une même semaine.
struct SwapDaysView: View {
    let cycle: Cycle
    let weekNumber: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allSessions: [CycleSession]

    @State private var dayA: Int = 2
    @State private var dayB: Int = 3

    private var canSwap: Bool { dayA != dayB }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Premier jour", selection: $dayA) {
                        ForEach(Weekday.ordered, id: \.weekday) { day in
                            Text(day.label).tag(day.weekday)
                        }
                    }
                    Picker("Second jour", selection: $dayB) {
                        ForEach(Weekday.ordered, id: \.weekday) { day in
                            Text(day.label).tag(day.weekday)
                        }
                    }
                } footer: {
                    Text("Toutes les séances de ces deux jours échangent de place, pour cette semaine uniquement.")
                }
            }
            .navigationTitle("Permuter deux jours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Permuter") {
                        swap()
                        dismiss()
                    }
                    .disabled(!canSwap)
                }
            }
        }
    }

    private func swap() {
        let sessions = allSessions.filter { $0.cycle?.id == cycle.id && $0.weekNumber == weekNumber }
        // Pré-découpé avant mutation, sinon les séances déplacées de A vers B seraient
        // re-basculées vers A par la seconde boucle.
        let aSessions = sessions.filter { $0.weekday == dayA }
        let bSessions = sessions.filter { $0.weekday == dayB }
        for session in aSessions { session.weekday = dayB }
        for session in bSessions { session.weekday = dayA }
    }
}
