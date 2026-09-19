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
    @Query private var allSessions: [CycleSession]

    @State private var kind: SessionKind = .musculation
    @State private var title: String = ""
    @State private var objective: PhysicalQuality?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AppSegmentedControl(options: SessionKind.allCases.map { ($0, $0.rawValue) }, selection: $kind)
                        .listRowInsets(EdgeInsets())
                        .padding(4)
                } header: { formSectionHeader("Type", required: true) }

                Section {
                    AppMenuField(
                        label: "Objectif",
                        placeholder: "Choisir un objectif",
                        options: PhysicalQuality.allCasesSortedAlphabetically.map { ($0, $0.rawValue) },
                        selection: $objective,
                        showsLabel: false
                    )
                } header: { formSectionHeader("Objectif de la séance", required: true) }

                Section {
                    TextField("Ex: Push improvisé", text: $title)
                } header: { formSectionHeader("Titre", required: true) }
            }
            .navigationTitle("Nouvelle séance")
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

    /// Les séances ad-hoc partageaient toutes un `order` fixe (999) : sans clé de tri stable,
    /// leur ordre d'affichage dépendait de l'ordre de retour du @Query et pouvait changer d'un
    /// chargement à l'autre. On les place maintenant après la dernière séance existante du jour,
    /// dans leur ordre de création.
    private func nextOrder(weekNumber: Int, weekday: Int) -> Int {
        let sameDaySessions: [CycleSession]
        if let cycle {
            sameDaySessions = allSessions.filter { $0.cycle?.id == cycle.id && $0.weekNumber == weekNumber && $0.weekday == weekday }
        } else {
            sameDaySessions = allSessions.filter {
                $0.cycle == nil && $0.isAdHoc && $0.adHocDate.map { Calendar.current.isDate($0, inSameDayAs: date) } == true
            }
        }
        return (sameDaySessions.map(\.order).max() ?? -1) + 1
    }

    private func save() {
        guard let objective else { return }
        let calendar = Calendar.current
        let weekNumber = cycle?.weekNumber(for: date) ?? 1
        let weekday = calendar.component(.weekday, from: date)
        let session = CycleSession(
            weekNumber: weekNumber,
            weekday: weekday,
            title: title,
            kind: kind,
            objective: objective,
            order: nextOrder(weekNumber: weekNumber, weekday: weekday),
            isAdHoc: true,
            adHocDate: cycle == nil ? date : nil
        )
        session.cycle = cycle
        context.insert(session)
        dismiss()
        onCreated(session)
    }
}
