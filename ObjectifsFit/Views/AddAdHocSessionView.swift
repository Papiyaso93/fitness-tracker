import SwiftUI
import SwiftData

/// Création rapide d'une séance non planifiée, loguée directement depuis l'Accueil — pas de plan
/// d'exercices associé, contrairement à une CycleSession créée via le constructeur de programme.
struct AddAdHocSessionView: View {
    let cycle: Cycle?
    let date: Date
    var onCreated: (CycleSession) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var kind: SessionKind = .musculation
    @State private var title: String = ""
    @State private var objective: PhysicalQuality?

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $kind) {
                        ForEach(SessionKind.allCases) { k in
                            Text(k.rawValue).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Titre*") {
                    TextField("Ex: Push improvisé", text: $title)
                }

                Section("Objectif de la séance*") {
                    Picker("Objectif", selection: $objective) {
                        Text("Choisir…").tag(PhysicalQuality?.none)
                        ForEach(PhysicalQuality.allCases) { quality in
                            Text(quality.rawValue).tag(PhysicalQuality?.some(quality))
                        }
                    }
                }
            }
            .navigationTitle("Nouvelle séance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || objective == nil)
                }
            }
        }
    }

    private func save() {
        guard let objective else { return }
        let calendar = Calendar.current
        let session = CycleSession(
            weekNumber: cycle?.weekNumber(for: date) ?? 1,
            weekday: calendar.component(.weekday, from: date),
            title: title,
            kind: kind,
            objective: objective,
            order: 999,
            isAdHoc: true,
            adHocDate: cycle == nil ? date : nil
        )
        session.cycle = cycle
        context.insert(session)
        dismiss()
        onCreated(session)
    }
}
