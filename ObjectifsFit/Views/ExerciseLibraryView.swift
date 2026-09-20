import SwiftUI
import SwiftData

/// Gestion de la bibliothèque d'exercices — créer, modifier, supprimer — accessible depuis les
/// Réglages plutôt que depuis le flux de log d'une série.
struct ExerciseLibraryView: View {
    @Query(sort: \ExerciseDefinition.name) private var exercises: [ExerciseDefinition]

    @State private var showingAddExercise = false
    @State private var expandedGroups: Set<String> = Set(MuscleGroupStyle.order)

    private var groupedExercises: [(group: String, exercises: [ExerciseDefinition])] {
        MuscleGroupStyle.order.compactMap { group in
            let matching = exercises.filter { $0.muscleGroup == group }
            return matching.isEmpty ? nil : (group, matching)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AppCard {
                    Button {
                        showingAddExercise = true
                    } label: {
                        HStack {
                            Text("Ajouter un exercice")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .buttonStyle(.plain)
                }

                ForEach(groupedExercises, id: \.group) { entry in
                    let isExpanded = expandedGroups.contains(entry.group)
                    Button {
                        if isExpanded {
                            expandedGroups.remove(entry.group)
                        } else {
                            expandedGroups.insert(entry.group)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            SectionLabel(text: "\(entry.group) (\(entry.exercises.count))")
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
                        VStack(spacing: 10) {
                            ForEach(entry.exercises) { exercise in
                                NavigationLink {
                                    EditExerciseDefinitionView(exercise: exercise)
                                } label: {
                                    AppCard {
                                        HStack {
                                            Text(exercise.name)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(AppTheme.textPrimary)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.background)
        .navigationTitle("Exercices")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseDefinitionView()
        }
    }
}
