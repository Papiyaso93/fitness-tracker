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
                Section("Muscle ciblé") {
                    Picker("Groupe musculaire", selection: $muscleGroup) {
                        Text("Choisir…").tag(String?.none)
                        ForEach(MuscleGroupStyle.order, id: \.self) { group in
                            Text(group).tag(String?.some(group))
                        }
                    }
                    .onChange(of: muscleGroup) { _, _ in
                        exerciseName = ""
                        isCreatingNewExercise = false
                    }

                    Picker("Exercice", selection: $exerciseName) {
                        Text("Choisir…").tag("")
                        ForEach(exerciseNamesForGroup, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .disabled(muscleGroup == nil)

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
                }

                Section("Type de série") {
                    Picker("Type", selection: $technique) {
                        ForEach(SetTechnique.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("Mode de résistance") {
                    Picker("Mode", selection: $resistanceMode) {
                        ForEach(ResistanceMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("Séries") {
                    LabeledContent("Nombre de séries") {
                        TextField("0", text: $targetSets)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if resistanceMode != .poidsDuCorps {
                        LabeledContent(weightFieldLabel) {
                            TextField("0", text: $targetWeight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("Répétitions") {
                    Picker("Type", selection: $isRepsRange) {
                        Text("Fourchette").tag(true)
                        Text("Précis").tag(false)
                    }
                    .pickerStyle(.segmented)
                    if isRepsRange {
                        LabeledContent("Min") {
                            TextField("0", text: $targetRepsMin)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Max") {
                            TextField("0", text: $targetRepsMax)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    } else {
                        LabeledContent("Répétitions") {
                            TextField("0", text: $targetRepsMin)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
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
