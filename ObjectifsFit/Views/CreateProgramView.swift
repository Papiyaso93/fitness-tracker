import SwiftUI
import SwiftData

/// Formulaire de création d'un programme (le conteneur long terme au-dessus des cycles).
struct CreateProgramView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var hasStartDate = false
    @State private var startDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var hasEndDate = false
    @State private var endDate: Date = Calendar.current.startOfDay(for: .now)

    @State private var principalDrafts: [ObjectiveDraft] = []
    @State private var secondaryDrafts: [ObjectiveDraft] = []
    @State private var addingCategory: ObjectiveCategory?

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        fieldCaption("Titre", required: true)
                        TextField("Programme 1 — Perte de gras", text: $title)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        fieldCaption("Description")
                        TextField("Résumé en une phrase", text: $description, axis: .vertical)
                    }
                } header: { formSectionHeader("Informations") }

                Section {
                    objectiveList(principalDrafts) { principalDrafts.remove(atOffsets: $0) }
                    Button {
                        addingCategory = .principal
                    } label: {
                        Label("Ajouter un objectif principal", systemImage: "plus.circle")
                    }
                } header: {
                    formSectionHeader("Objectifs principaux")
                } footer: {
                    Text("Deux objectifs maximum recommandés, pour rester concentré sur l'essentiel. Idéalement mesurables.")
                }

                Section {
                    objectiveList(secondaryDrafts) { secondaryDrafts.remove(atOffsets: $0) }
                    Button {
                        addingCategory = .indicateur
                    } label: {
                        Label("Ajouter un indicateur", systemImage: "plus.circle")
                    }
                } header: {
                    formSectionHeader("Indicateurs à suivre")
                } footer: {
                    Text("Aucune limite — des repères à suivre en complément des objectifs principaux.")
                }

                Section {
                    Toggle("Date de début", isOn: $hasStartDate)
                    if hasStartDate {
                        DatePicker(selection: $startDate, displayedComponents: .date) { EmptyView() }
                    }
                    Toggle("Date de fin", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker(selection: $endDate, displayedComponents: .date) { EmptyView() }
                    }
                } header: {
                    formSectionHeader("Dates")
                } footer: {
                    Text("Permet de situer les objectifs dans le temps.")
                }
            }
            .navigationTitle("Nouveau programme")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { save() }
                        .disabled(!canSave)
                }
            }
            .sheet(item: $addingCategory) { category in
                AddObjectiveDraftView { draft in
                    if category == .principal {
                        principalDrafts.append(draft)
                    } else {
                        secondaryDrafts.append(draft)
                    }
                }
            }
        }
    }

    private func objectiveList(_ drafts: [ObjectiveDraft], onDelete: @escaping (IndexSet) -> Void) -> some View {
        ForEach(drafts) { draft in
            HStack {
                Text(draft.summary)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button {
                    if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
                        onDelete(IndexSet(integer: index))
                    }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .onDelete(perform: onDelete)
    }

    private func save() {
        let status: ProgramStatus = (hasStartDate && startDate > .now) ? .aVenir : .enCours
        let program = TrainingProgram(
            title: title.trimmingCharacters(in: .whitespaces),
            programDescription: description.isEmpty ? nil : description,
            startDate: hasStartDate ? startDate : nil,
            endDate: hasEndDate ? endDate : nil,
            status: status
        )
        context.insert(program)

        for (index, draft) in principalDrafts.enumerated() {
            context.insert(makeObjective(draft, category: .principal, order: index, program: program))
        }
        for (index, draft) in secondaryDrafts.enumerated() {
            context.insert(makeObjective(draft, category: .indicateur, order: index, program: program))
        }

        dismiss()
    }

    private func makeObjective(_ draft: ObjectiveDraft, category: ObjectiveCategory, order: Int, program: TrainingProgram) -> ProgramObjective {
        let objective = ProgramObjective(
            category: category,
            isMeasurable: draft.isMeasurable,
            freeText: draft.isMeasurable ? nil : draft.freeText,
            metricType: draft.isMeasurable ? draft.metricType : nil,
            mode: draft.isMeasurable ? draft.mode : nil,
            startValue: draft.isMeasurable && draft.mode == .progression ? Double(draft.startValue) : nil,
            targetValue: draft.isMeasurable ? Double(draft.targetValue) : nil,
            order: order
        )
        objective.program = program
        return objective
    }
}
