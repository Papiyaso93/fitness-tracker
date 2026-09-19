import SwiftUI
import SwiftData

/// Édition d'un programme déjà créé : infos, objectifs (ajout/suppression directs, le programme
/// existe déjà en base), dates, et suppression du programme entier.
struct EditProgramView: View {
    @Bindable var program: TrainingProgram
    var onDelete: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var hasStartDate: Bool
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var addingCategory: ObjectiveCategory?
    @State private var showingDeleteConfirmation = false

    init(program: TrainingProgram, onDelete: @escaping () -> Void) {
        self.program = program
        self.onDelete = onDelete
        _hasStartDate = State(initialValue: program.startDate != nil)
        _startDate = State(initialValue: program.startDate ?? Calendar.current.startOfDay(for: .now))
        _hasEndDate = State(initialValue: program.endDate != nil)
        _endDate = State(initialValue: program.endDate ?? Calendar.current.startOfDay(for: .now))
    }

    private var canSave: Bool {
        !program.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Programme 1 — Perte de gras", text: $program.title)
                } header: { formSectionHeader("Titre", required: true) }

                Section {
                    TextField("Résumé en une phrase", text: Binding(
                        get: { program.programDescription ?? "" },
                        set: { program.programDescription = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                } header: { formSectionHeader("Description") }

                Section {
                    objectiveList(program.principalObjectives)
                    if program.principalObjectives.isEmpty {
                        addObjectiveRow(label: "Ajouter un objectif") { addingCategory = .principal }
                    }
                } header: {
                    sectionHeaderWithAdd("Objectifs principaux", isEmpty: program.principalObjectives.isEmpty) { addingCategory = .principal }
                } footer: {
                    Text("Deux maximum recommandés, idéalement mesurables.")
                }

                Section {
                    objectiveList(program.secondaryObjectives)
                    if program.secondaryObjectives.isEmpty {
                        addObjectiveRow(label: "Ajouter un indicateur") { addingCategory = .indicateur }
                    }
                } header: {
                    sectionHeaderWithAdd("Indicateurs à suivre", isEmpty: program.secondaryObjectives.isEmpty) { addingCategory = .indicateur }
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

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Text("Supprimer le programme")
                    }
                }
            }
            .navigationTitle("Modifier le programme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminer") {
                        program.startDate = hasStartDate ? startDate : nil
                        program.endDate = hasEndDate ? endDate : nil
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(item: $addingCategory) { category in
                AddObjectiveDraftView { draft in
                    let objective = ProgramObjective(
                        category: category,
                        isMeasurable: draft.isMeasurable,
                        freeText: draft.isMeasurable ? nil : draft.freeText,
                        metricType: draft.isMeasurable ? draft.metricType : nil,
                        customMetricName: draft.customMetricName,
                        customUnit: draft.customUnit,
                        mode: draft.isMeasurable ? draft.mode : nil,
                        startValue: draft.isMeasurable && draft.mode == .progression ? Double(draft.startValue) : nil,
                        targetValue: draft.isMeasurable ? Double(draft.targetValue) : nil,
                        order: category == .principal ? program.principalObjectives.count : program.secondaryObjectives.count
                    )
                    objective.program = program
                    context.insert(objective)
                }
            }
            .confirmationDialog(
                "Supprimer ce programme ?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) {
                    context.delete(program)
                    onDelete()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Ses cycles seront aussi supprimés. Cette action est irréversible.")
            }
        }
    }

    /// Ligne "Ajouter…" affichée tant qu'aucun objectif/indicateur n'existe — une fois le premier
    /// ajouté, l'ajout suivant se fait via le "+" du header de Section (sectionHeaderWithAdd).
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

    private func objectiveList(_ objectives: [ProgramObjective]) -> some View {
        ForEach(objectives) { objective in
            HStack {
                objectiveSummaryText(objective)
                    .padding(.vertical, 4)
                Spacer()
                Button {
                    context.delete(objective)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Découpe "Nom : valeur" pour mettre le nom en avant sur sa propre ligne — même traitement
    /// que la carte de brouillon en création, sans couleur d'accent sur la valeur.
    private func objectiveSummaryText(_ objective: ProgramObjective) -> some View {
        let parts = objective.summary.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        return VStack(alignment: .leading, spacing: 4) {
            if parts.count == 2 {
                Text(parts[0]).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppTheme.textPrimary)
                Text(parts[1]).font(.system(size: 13)).foregroundStyle(AppTheme.textSecondary)
            } else {
                Text(objective.summary)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
    }
}
