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
                    TextField("Programme 1 — Perte de gras", text: $title)
                } header: { formSectionHeader("Titre", required: true) }

                Section {
                    TextField("Résumé en une phrase", text: $description, axis: .vertical)
                } header: { formSectionHeader("Description") }

                Section {
                    objectiveList(principalDrafts) { principalDrafts.remove(atOffsets: $0) }
                    if principalDrafts.isEmpty {
                        addObjectiveRow(label: "Ajouter un objectif") { addingCategory = .principal }
                    }
                } header: {
                    sectionHeaderWithAdd("Objectifs principaux", isEmpty: principalDrafts.isEmpty) { addingCategory = .principal }
                } footer: {
                    Text("Deux maximum recommandés, idéalement mesurables.")
                }

                Section {
                    objectiveList(secondaryDrafts) { secondaryDrafts.remove(atOffsets: $0) }
                    if secondaryDrafts.isEmpty {
                        addObjectiveRow(label: "Ajouter un indicateur") { addingCategory = .indicateur }
                    }
                } header: {
                    sectionHeaderWithAdd("Indicateurs à suivre", isEmpty: secondaryDrafts.isEmpty) { addingCategory = .indicateur }
                } footer: {
                    Text("Des repères en complément des objectifs principaux.")
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

    /// Ligne "Ajouter…" affichée tant qu'aucun objectif/indicateur n'existe — une fois le premier
    /// ajouté, l'ajout suivant se fait via le "+" du header de Section (sectionHeaderWithAdd),
    /// pour ne pas dupliquer l'action une fois que la liste n'est plus vide.
    private func addObjectiveRow(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .buttonStyle(.plain)
    }

    private func sectionHeaderWithAdd(_ title: String, isEmpty: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            formSectionHeader(title)
            Spacer()
            if !isEmpty {
                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .padding(.bottom, 6)
    }

    private func objectiveList(_ drafts: [ObjectiveDraft], onDelete: @escaping (IndexSet) -> Void) -> some View {
        ForEach(drafts) { draft in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    if let progressionText = draft.progressionText {
                        Text(progressionText)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
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
