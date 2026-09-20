import SwiftUI
import SwiftData

/// Édition d'un exercice existant — édition en direct + suppression, même pattern que
/// Repas/Transit/Sommeil/Rappels.
struct EditExerciseDefinitionView: View {
    @Bindable var exercise: ExerciseDefinition
    @Query private var allExercises: [ExerciseDefinition]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var coefficientText: String

    init(exercise: ExerciseDefinition) {
        self.exercise = exercise
        _coefficientText = State(initialValue: String(format: "%.2f", exercise.tonnageCoefficient))
    }

    private var muscleGroupBinding: Binding<String?> {
        Binding(get: { exercise.muscleGroup }, set: { if let newValue = $0 { exercise.muscleGroup = newValue } })
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

    private var primaryMusclesBinding: Binding<Set<String>> {
        Binding(get: { Set(exercise.primaryMuscles) }, set: { exercise.primaryMuscles = Array($0).sorted() })
    }

    private var secondaryMusclesBinding: Binding<Set<String>> {
        Binding(get: { Set(exercise.secondaryMuscles) }, set: { exercise.secondaryMuscles = Array($0).sorted() })
    }

    var body: some View {
        Form {
            Section {
                TextField("Nom", text: $exercise.name)
            } header: { formSectionHeader("Nom", required: true) }

            Section {
                AppMenuField(
                    label: "Groupe musculaire",
                    options: MuscleGroupStyle.order.map { ($0, $0) },
                    selection: muscleGroupBinding,
                    required: true,
                    showsLabel: false
                )
            } header: { formSectionHeader("Groupe musculaire", required: true) }

            Section {
                NavigationLink {
                    MuscleSelectionView(title: "Muscles principaux", musclesWithGroups: allKnownMuscles, selection: primaryMusclesBinding)
                } label: {
                    muscleSummaryRow(exercise.primaryMuscles)
                }
            } header: { formSectionHeader("Muscles principaux") }

            Section {
                NavigationLink {
                    MuscleSelectionView(title: "Muscles secondaires", musclesWithGroups: allKnownMuscles, selection: secondaryMusclesBinding)
                } label: {
                    muscleSummaryRow(exercise.secondaryMuscles)
                }
            } header: { formSectionHeader("Muscles secondaires") }

            Section {
                LabeledContent {
                    TextField("1.00", text: $coefficientText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: coefficientText) { _, newValue in
                            if let value = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                exercise.tonnageCoefficient = value
                            }
                        }
                } label: {
                    fieldLabel("Coefficient")
                }
            } header: {
                formSectionHeader("Coefficient tonnage")
            } footer: {
                Text("Concerne les exercices au poids du corps.")
            }

            Section {
                Button("Supprimer cet exercice", role: .destructive) {
                    context.delete(exercise)
                    dismiss()
                }
            }
        }
        .navigationTitle("Exercice")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func muscleSummaryRow(_ muscles: [String]) -> some View {
        HStack {
            Text(muscles.isEmpty ? "Aucun" : muscles.joined(separator: ", "))
                .foregroundStyle(muscles.isEmpty ? Color(hex: "B4AFA6") : AppTheme.textPrimary)
            Spacer()
        }
    }
}
