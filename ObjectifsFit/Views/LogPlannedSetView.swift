import SwiftUI
import SwiftData

/// Log d'une série réellement effectuée contre une CycleSession — même flow que LogExerciseSetView
/// (ancien système), branché sur les nouvelles données.
struct LogPlannedSetView: View {
    let completion: SessionCompletion
    let suggestedExercises: [PlannedExercise]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MetricEntry.date) private var metricEntries: [MetricEntry]
    @Query(sort: \ExerciseDefinition.name) private var exerciseLibrary: [ExerciseDefinition]

    @State private var muscleGroup: String?
    @State private var exerciseName: String = ""

    @State private var technique: SetTechnique = .normal
    @State private var techniqueOtherLabel: String = ""
    @State private var linkToPrevious = false

    @State private var resistanceMode: ResistanceMode = .poidsLibre

    @State private var weight: String = ""
    @State private var bodyWeight: String = ""
    @State private var addedWeight: String = ""
    @State private var reps: String = ""
    @State private var sensation: SensationLevel = .difficile
    @State private var comment: String = ""

    private var latestBodyWeight: Double? {
        metricEntries.filter { $0.type == .poids }.sorted { $0.date > $1.date }.first?.value
    }

    private var defaultCoefficient: Double {
        BodyweightCoefficients.defaultCoefficient(forExerciseNamed: exerciseName.isEmpty ? (muscleGroup ?? "") : exerciseName)
    }

    private var exerciseNamesForGroup: [String] {
        guard let muscleGroup else { return [] }
        let planNames = suggestedExercises.filter { $0.muscleGroup == muscleGroup }.map(\.exerciseName)
        let libraryNames = exerciseLibrary.filter { $0.muscleGroup == muscleGroup }.map(\.name)
        return Array(Set(planNames + libraryNames)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
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
                    .onChange(of: muscleGroup) { _, _ in exerciseName = "" }

                    Picker("Exercice", selection: $exerciseName) {
                        Text("Choisir…").tag("")
                        ForEach(exerciseNamesForGroup, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .disabled(muscleGroup == nil)
                }

                if !exerciseName.isEmpty {
                    Section("Technique") {
                        Picker("Type de série", selection: $technique) {
                            ForEach(SetTechnique.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        if technique == .autre {
                            TextField("Préciser la technique", text: $techniqueOtherLabel)
                        }
                        if technique != .normal {
                            Toggle("Lier à la série précédente", isOn: $linkToPrevious)
                        }
                    }

                    Section("Mode de résistance") {
                        Picker("Mode", selection: $resistanceMode) {
                            ForEach(ResistanceMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        if resistanceMode == .poidsDuCorps || resistanceMode == .leste {
                            LabeledContent("Coefficient tonnage") {
                                Text("\(defaultCoefficient, specifier: "%.2f")")
                            }
                        }
                    }

                    Section("Série") {
                        weightFields
                        LabeledContent("Répétitions") {
                            TextField("0", text: $reps)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        Picker("Sensation", selection: $sensation) {
                            ForEach(SensationLevel.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Commentaire").foregroundStyle(AppTheme.textSecondary).font(.system(size: 13))
                            TextField("Optionnel", text: $comment, axis: .vertical)
                        }
                    }
                }
            }
            .navigationTitle("Nouvelle série")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { save() }
                        .disabled(exerciseName.isEmpty || Int(reps) == nil)
                }
            }
            .onAppear {
                if bodyWeight.isEmpty, let latestBodyWeight {
                    bodyWeight = String(format: "%.1f", latestBodyWeight)
                }
            }
        }
    }

    @ViewBuilder
    private var weightFields: some View {
        switch resistanceMode {
        case .poidsLibre, .machine:
            LabeledContent("Poids (kg)") {
                TextField("0", text: $weight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        case .poidsDuCorps:
            LabeledContent("Poids de corps (kg)") {
                TextField("0", text: $bodyWeight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            if latestBodyWeight != nil {
                Text("Pré-rempli depuis ta dernière pesée").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
            }
        case .leste:
            LabeledContent("Poids de corps (kg)") {
                TextField("0", text: $bodyWeight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Charge ajoutée (kg)") {
                TextField("0", text: $addedWeight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        case .elastique:
            LabeledContent("Poids indiqué (kg)") {
                TextField("0", text: $weight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            Text("Exclu du tonnage/charge moyenne (résistance non constante, pas comparable à une haltère).")
                .font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var weightValue: Double? {
        switch resistanceMode {
        case .poidsLibre, .machine, .elastique: return Double(weight)
        case .leste: return Double(addedWeight)
        case .poidsDuCorps: return nil
        }
    }

    private func save() {
        guard let repsValue = Int(reps) else { return }

        var groupId: UUID?
        if technique != .normal {
            if linkToPrevious, let last = completion.setEntries.sorted(by: { $0.date < $1.date }).last, last.technique == technique {
                groupId = last.groupId ?? UUID()
                last.groupId = groupId
            } else {
                groupId = UUID()
            }
        }

        let coefficient: Double = (resistanceMode == .poidsDuCorps || resistanceMode == .leste) ? defaultCoefficient : 1.0

        let entry = PlannedSetEntry(
            exerciseName: exerciseName,
            muscleGroup: muscleGroup ?? "",
            resistanceMode: resistanceMode,
            weight: weightValue,
            bodyWeight: (resistanceMode == .poidsDuCorps || resistanceMode == .leste) ? Double(bodyWeight) : nil,
            reps: repsValue,
            sensation: sensation,
            comment: comment.isEmpty ? nil : comment,
            coefficient: coefficient,
            technique: technique,
            techniqueOtherLabel: technique == .autre ? techniqueOtherLabel : nil,
            groupId: groupId
        )
        entry.completion = completion
        context.insert(entry)
        dismiss()
    }
}
