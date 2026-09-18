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
                    Picker(selection: $muscleGroup) {
                        Text("Choisir…").tag(String?.none)
                        ForEach(MuscleGroupStyle.order, id: \.self) { group in
                            Text(group).tag(String?.some(group))
                        }
                    } label: {
                        fieldLabel("Groupe musculaire", required: true)
                    }
                    .onChange(of: muscleGroup) { _, _ in
                        if !exerciseNamesForGroup.contains(exerciseName) { exerciseName = "" }
                    }

                    Picker(selection: $exerciseName) {
                        Text("Choisir…").tag("")
                        ForEach(exerciseNamesForGroup, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    } label: {
                        fieldLabel("Exercice", required: true)
                    }
                    .disabled(muscleGroup == nil)
                } header: { formSectionHeader("Muscle ciblé", required: true) }

                if !exerciseName.isEmpty {
                    Section {
                        Picker("Type de série", selection: $technique) {
                            ForEach(SetTechnique.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        if technique == .autre {
                            TextField("Préciser la technique", text: $techniqueOtherLabel)
                        }
                        if technique != .normal {
                            Toggle("Lier à la série précédente", isOn: $linkToPrevious)
                        }
                    } header: { formSectionHeader("Technique", required: true) }

                    Section {
                        Picker("Mode", selection: $resistanceMode) {
                            ForEach(ResistanceMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        if resistanceMode == .poidsDuCorps || resistanceMode == .leste {
                            LabeledContent("Coefficient tonnage") {
                                Text("\(defaultCoefficient, specifier: "%.2f")")
                            }
                        }
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
                        Picker(selection: $sensation) {
                            ForEach(SensationLevel.allCases, id: \.self) { Text($0.label).tag($0) }
                        } label: {
                            fieldLabel("Sensation", required: true)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            fieldCaption("Commentaire")
                            TextField("Optionnel", text: $comment, axis: .vertical)
                        }
                    } header: { formSectionHeader("Série") }
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
