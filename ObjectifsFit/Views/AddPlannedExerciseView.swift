import SwiftUI
import SwiftData

/// Brouillon d'exercice planifié, avant que la séance ne soit enregistrée.
struct PlannedExerciseDraft: Identifiable {
    let id = UUID()
    var muscleGroup: String = ""
    var exerciseName: String = ""
    var technique: SetTechnique = .normal
    var resistanceMode: ResistanceMode = .poidsLibre
    var targetSets: String = ""
    var targetWeight: String = ""
    var isRepsRange: Bool = true
    var targetRepsMin: String = ""
    var targetRepsMax: String = ""

    /// "Machine · 2 séries · 110kg · 8-10 reps" — même format que SessionDetailView.
    var summary: String {
        let sets = targetSets.isEmpty ? "?" : targetSets
        let reps: String = {
            if isRepsRange {
                return "\(targetRepsMin.isEmpty ? "?" : targetRepsMin)-\(targetRepsMax.isEmpty ? "?" : targetRepsMax)"
            }
            return targetRepsMin.isEmpty ? "?" : targetRepsMin
        }()
        var parts = [resistanceMode.rawValue, "\(sets) séries"]
        if resistanceMode != .poidsDuCorps && resistanceMode != .elastique && !targetWeight.isEmpty {
            parts.append("\(targetWeight)kg")
        }
        parts.append("\(reps) reps")
        return parts.joined(separator: " · ")
    }
}

/// Formulaire d'ajout d'un exercice à une séance de musculation planifiée.
struct AddPlannedExerciseView: View {
    let onSave: (PlannedExerciseDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \ExerciseDefinition.name) private var exerciseLibrary: [ExerciseDefinition]

    @State private var muscleGroup: String?
    @State private var exerciseName: String = ""
    @State private var isCreatingNewExercise = false
    @State private var newExerciseName = ""
    @State private var technique: SetTechnique = .normal
    @State private var resistanceMode: ResistanceMode = .poidsLibre
    @State private var targetSets: String = ""
    @State private var targetWeight: String = ""
    @State private var isRepsRange = true
    @State private var targetRepsMin: String = ""
    @State private var targetRepsMax: String = ""

    private var exerciseNamesForGroup: [String] {
        guard let muscleGroup else { return [] }
        return exerciseLibrary
            .filter { $0.muscleGroup == muscleGroup }
            .map(\.name)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var canSave: Bool {
        !exerciseName.isEmpty && Int(targetSets) != nil && Int(targetRepsMin) != nil && (isRepsRange ? Int(targetRepsMax) != nil : true)
    }

    private var weightFieldLabel: String {
        resistanceMode == .leste ? "Charge ajoutée (kg)" : "Poids cible (kg)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AppMenuField(
                        label: "Groupe musculaire",
                        options: MuscleGroupStyle.order.map { ($0, $0) },
                        selection: $muscleGroup,
                        required: true
                    )
                    .onChange(of: muscleGroup) { _, _ in
                        exerciseName = ""
                        isCreatingNewExercise = false
                    }

                    if muscleGroup != nil {
                        AppMenuField(
                            label: "Exercice",
                            options: exerciseNamesForGroup.map { ($0, $0) },
                            selection: Binding(
                                get: { exerciseName.isEmpty ? nil : exerciseName },
                                set: { exerciseName = $0 ?? "" }
                            ),
                            required: true
                        )
                    }

                    if isCreatingNewExercise {
                        TextField("Nom de l'exercice", text: $newExerciseName)
                        Button("Enregistrer cet exercice") {
                            let trimmed = newExerciseName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty, let muscleGroup else { return }
                            context.insert(ExerciseDefinition(name: trimmed, muscleGroup: muscleGroup))
                            exerciseName = trimmed
                            isCreatingNewExercise = false
                            newExerciseName = ""
                        }
                        .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                    } else {
                        Button {
                            isCreatingNewExercise = true
                        } label: {
                            Label("Créer un nouvel exercice", systemImage: "plus.circle")
                        }
                        .disabled(muscleGroup == nil)
                    }
                } header: { formSectionHeader("Muscle ciblé", required: true) }

                Section {
                    AppMenuField(
                        label: "Type",
                        options: SetTechnique.allCases.map { ($0, $0.label) },
                        selection: $technique,
                        required: true,
                        showsLabel: false
                    )
                } header: { formSectionHeader("Type de série", required: true) }

                Section {
                    AppMenuField(
                        label: "Mode",
                        options: ResistanceMode.allCases.map { ($0, $0.rawValue) },
                        selection: $resistanceMode,
                        required: true,
                        showsLabel: false
                    )
                } header: { formSectionHeader("Mode de résistance", required: true) }

                Section {
                    LabeledContent {
                        TextField("0", text: $targetSets)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        fieldLabel("Nombre de séries", required: true)
                    }
                    if resistanceMode != .poidsDuCorps {
                        LabeledContent(weightFieldLabel) {
                            TextField("0", text: $targetWeight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } header: { formSectionHeader("Séries") }

                Section {
                    AppSegmentedControl(options: [(true, "Fourchette"), (false, "Précis")], selection: $isRepsRange)
                        .listRowInsets(EdgeInsets())
                        .padding(4)
                    if isRepsRange {
                        LabeledContent {
                            TextField("0", text: $targetRepsMin)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        } label: {
                            fieldLabel("Min", required: true)
                        }
                        LabeledContent {
                            TextField("0", text: $targetRepsMax)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        } label: {
                            fieldLabel("Max", required: true)
                        }
                    } else {
                        LabeledContent {
                            TextField("0", text: $targetRepsMin)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        } label: {
                            fieldLabel("Répétitions", required: true)
                        }
                    }
                } header: { formSectionHeader("Répétitions") }
            }
            .navigationTitle("Nouvel exercice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        var draft = PlannedExerciseDraft()
                        draft.muscleGroup = muscleGroup ?? ""
                        draft.exerciseName = exerciseName
                        draft.technique = technique
                        draft.resistanceMode = resistanceMode
                        draft.targetSets = targetSets
                        draft.targetWeight = targetWeight
                        draft.isRepsRange = isRepsRange
                        draft.targetRepsMin = targetRepsMin
                        draft.targetRepsMax = isRepsRange ? targetRepsMax : targetRepsMin
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
