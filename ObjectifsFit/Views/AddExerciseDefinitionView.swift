import SwiftUI
import SwiftData

/// Création d'un exercice dans la bibliothèque personnelle — mêmes champs que l'édition (sans
/// suppression, qui n'a pas de sens avant que l'exercice existe).
struct AddExerciseDefinitionView: View {
    @Query private var allExercises: [ExerciseDefinition]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String = ""
    @State private var muscleGroup: String?
    @State private var primaryMuscles: Set<String> = []
    @State private var secondaryMuscles: Set<String> = []
    @State private var coefficientText = "1.00"
    @State private var coefficientManuallyEdited = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && muscleGroup != nil
    }

    /// Tous les muscles déjà utilisés dans la bibliothèque, avec le(s) groupe(s) d'exercices où
    /// chacun apparaît — sert de liste de sélection groupée, sans liste séparée à maintenir à la main.
    private var allKnownMuscles: [(muscle: String, groups: Set<String>)] {
        var groupsByMuscle: [String: Set<String>] = [:]
        for definition in allExercises {
            for muscle in definition.primaryMuscles + definition.secondaryMuscles {
                groupsByMuscle[muscle, default: []].insert(definition.muscleGroup)
            }
        }
        return groupsByMuscle.map { (muscle: $0.key, groups: $0.value) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ex: Développé couché", text: $name)
                        .onChange(of: name) { _, newValue in
                            guard !coefficientManuallyEdited else { return }
                            coefficientText = String(format: "%.2f", BodyweightCoefficients.defaultCoefficient(forExerciseNamed: newValue))
                        }
                } header: { formSectionHeader("Nom", required: true) }

                Section {
                    AppMenuField(
                        label: "Groupe musculaire",
                        options: MuscleGroupStyle.order.map { ($0, $0) },
                        selection: $muscleGroup,
                        required: true,
                        showsLabel: false
                    )
                } header: { formSectionHeader("Groupe musculaire", required: true) }

                Section {
                    NavigationLink {
                        MuscleSelectionView(title: "Muscles principaux", musclesWithGroups: allKnownMuscles, selection: $primaryMuscles)
                    } label: {
                        muscleSummaryRow(primaryMuscles)
                    }
                } header: { formSectionHeader("Muscles principaux") }

                Section {
                    NavigationLink {
                        MuscleSelectionView(title: "Muscles secondaires", musclesWithGroups: allKnownMuscles, selection: $secondaryMuscles)
                    } label: {
                        muscleSummaryRow(secondaryMuscles)
                    }
                } header: { formSectionHeader("Muscles secondaires") }

                Section {
                    LabeledContent {
                        TextField("1.00", text: $coefficientText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: coefficientText) { _, _ in coefficientManuallyEdited = true }
                    } label: {
                        fieldLabel("Coefficient")
                    }
                } header: {
                    formSectionHeader("Coefficient tonnage")
                } footer: {
                    Text("Concerne les exercices au poids du corps.")
                }
            }
            .navigationTitle("Nouvel exercice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func muscleSummaryRow(_ muscles: Set<String>) -> some View {
        HStack {
            Text(muscles.isEmpty ? "Aucun" : muscles.sorted().joined(separator: ", "))
                .foregroundStyle(muscles.isEmpty ? Color(hex: "B4AFA6") : AppTheme.textPrimary)
            Spacer()
        }
    }

    private func save() {
        guard let muscleGroup else { return }
        let coefficient = Double(coefficientText.replacingOccurrences(of: ",", with: "."))
        let exercise = ExerciseDefinition(
            name: name.trimmingCharacters(in: .whitespaces),
            muscleGroup: muscleGroup,
            primaryMuscles: primaryMuscles.sorted(),
            secondaryMuscles: secondaryMuscles.sorted(),
            tonnageCoefficient: coefficient
        )
        context.insert(exercise)
        dismiss()
    }
}
