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
                    VStack(alignment: .leading, spacing: 4) {
                        fieldCaption("Titre", required: true)
                        TextField("Programme 1 — Perte de gras", text: $program.title)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        fieldCaption("Description")
                        TextField("Résumé en une phrase", text: Binding(
                            get: { program.programDescription ?? "" },
                            set: { program.programDescription = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                    }
                } header: { formSectionHeader("Informations") }

                Section {
                    objectiveList(program.principalObjectives)
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
                    objectiveList(program.secondaryObjectives)
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

    private func objectiveList(_ objectives: [ProgramObjective]) -> some View {
        ForEach(objectives) { objective in
            HStack {
                Text(objective.summary)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
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
}
