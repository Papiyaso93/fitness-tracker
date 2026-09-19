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
    @State private var reusedFromPrevious = false

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

    private var previousEntry: PlannedSetEntry? {
        completion.setEntries.sorted { $0.date < $1.date }.last
    }

    private func weightSummary(for entry: PlannedSetEntry) -> String {
        switch entry.resistanceMode {
        case .poidsDuCorps: return "\(entry.reps) reps"
        default:
            let weightLabel = entry.weight.map { "\(Int($0))kg" } ?? ""
            return "\(weightLabel) · \(entry.reps) reps"
        }
    }

    private var selectedExerciseDefinition: ExerciseDefinition? {
        exerciseLibrary.first { $0.name == exerciseName && $0.muscleGroup == muscleGroup }
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
                if let previousEntry, !reusedFromPrevious {
                    Button {
                        applyPreviousEntry(previousEntry)
                    } label: {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 13))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Reprendre la série précédente")
                                    .font(.system(size: 13, weight: .medium))
                                    .underline()
                                Text("(\(previousEntry.exerciseName) · \(weightSummary(for: previousEntry)))")
                                    .font(.system(size: 13))
                            }
                        }
                        .foregroundStyle(AppTheme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(AppTheme.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                } else if reusedFromPrevious {
                    HStack {
                        Label("Repris de la série précédente", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.secondary)
                        Spacer()
                        Button("Annuler") { resetToBlank() }
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Section {
                    AppMenuField(
                        label: "Groupe musculaire",
                        options: MuscleGroupStyle.order.map { ($0, $0) },
                        selection: $muscleGroup,
                        required: true
                    )
                    .onChange(of: muscleGroup) { _, _ in
                        if !exerciseNamesForGroup.contains(exerciseName) { exerciseName = "" }
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

                    if let definition = selectedExerciseDefinition, !definition.primaryMuscles.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            (Text("Principal : ").foregroundStyle(AppTheme.textSecondary)
                                + Text(definition.primaryMuscles.joined(separator: ", ")).foregroundStyle(AppTheme.secondary))
                                .font(.system(size: 12, weight: .medium))
                            if !definition.secondaryMuscles.isEmpty {
                                (Text("Secondaire : ").foregroundStyle(AppTheme.textSecondary)
                                    + Text(definition.secondaryMuscles.joined(separator: ", ")).foregroundStyle(AppTheme.textSecondary))
                                    .font(.system(size: 12))
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                } header: { formSectionHeader("Muscle ciblé", required: true) }

                if !exerciseName.isEmpty {
                    Section {
                        AppMenuField(
                            label: "Type de série",
                            options: SetTechnique.allCases.map { ($0, $0.label) },
                            selection: $technique,
                            required: true,
                            showsLabel: false
                        )
                        if technique == .autre {
                            TextField("Préciser la technique", text: $techniqueOtherLabel)
                        }
                        if technique != .normal {
                            Toggle("Lier à la série précédente", isOn: $linkToPrevious)
                        }
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
                        weightFields
                        LabeledContent {
                            TextField("0", text: $reps)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        } label: {
                            fieldLabel("Répétitions", required: true)
                        }
                        AppMenuField(
                            label: "Sensation",
                            options: SensationLevel.allCases.map { ($0, $0.label) },
                            selection: $sensation,
                            required: true
                        )
                    } header: { formSectionHeader("Série") }

                    Section {
                        TextField("Optionnel", text: $comment, axis: .vertical)
                    } header: { formSectionHeader("Commentaire") }
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
            weightRow(label: "Poids (kg)", required: technique == .normal, binding: $weight)
        case .poidsDuCorps:
            weightRow(
                label: "Poids corps (kg)",
                required: true,
                binding: $bodyWeight,
                notes: [
                    latestBodyWeight != nil ? "Pré-rempli depuis ta dernière pesée" : nil,
                    "Coefficient tonnage : \(String(format: "%.2f", defaultCoefficient))"
                ].compactMap { $0 }
            )
        case .leste:
            weightRow(label: "Poids corps (kg)", required: true, binding: $bodyWeight)
            weightRow(
                label: "Lest ajouté (kg)",
                required: true,
                binding: $addedWeight,
                notes: ["Coefficient tonnage (poids total) : \(String(format: "%.2f", defaultCoefficient))"]
            )
        case .elastique:
            weightRow(
                label: "Résistance (kg)",
                required: true,
                binding: $weight,
                notes: ["Indicatif, non utilisé dans les calculs de tonnage."]
            )
        }
    }

    /// Même disposition que "Répétitions" (label à gauche, valeur à droite, une seule ligne) —
    /// `.lineLimit(1)` + `.layoutPriority(1)` empêchent l'astérisque de passer à la ligne suivante
    /// en laissant le champ céder l'espace en premier. Les labels sont volontairement courts
    /// ("Poids corps", "Lest ajouté", "Résistance") pour tenir sur une ligne avec l'astérisque sans
    /// réduction de police. Les notes restent dans la même Form row que le champ pour ne pas faire
    /// apparaître de séparateur entre elles et lui.
    private func weightRow(label: String, required: Bool, binding: Binding<String>, notes: [String] = []) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent {
                TextField("0", text: binding)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            } label: {
                fieldLabel(label, required: required)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            ForEach(notes, id: \.self) { note in
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var weightValue: Double? {
        switch resistanceMode {
        case .poidsLibre, .machine, .elastique: return Double(weight)
        case .leste: return Double(addedWeight)
        case .poidsDuCorps: return nil
        }
    }

    private func applyPreviousEntry(_ entry: PlannedSetEntry) {
        muscleGroup = entry.muscleGroup
        exerciseName = entry.exerciseName
        resistanceMode = entry.resistanceMode
        reps = String(entry.reps)
        sensation = entry.sensation
        switch entry.resistanceMode {
        case .poidsLibre, .machine, .elastique:
            weight = entry.weight.map { String(format: "%.1f", $0) } ?? ""
        case .leste:
            addedWeight = entry.weight.map { String(format: "%.1f", $0) } ?? ""
            bodyWeight = entry.bodyWeight.map { String(format: "%.1f", $0) } ?? bodyWeight
        case .poidsDuCorps:
            bodyWeight = entry.bodyWeight.map { String(format: "%.1f", $0) } ?? bodyWeight
        }
        reusedFromPrevious = true
    }

    private func resetToBlank() {
        muscleGroup = nil
        exerciseName = ""
        resistanceMode = .poidsLibre
        weight = ""
        addedWeight = ""
        reps = ""
        sensation = .difficile
        reusedFromPrevious = false
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
