import SwiftUI

/// Un même nom de muscle peut apparaître dans les listes secondaires d'exercices de plusieurs
/// groupes différents (ex: "Trapèzes" cité en secondaire d'exercices Dos et Épaules) sans que ce
/// soit son groupe anatomique réel — ce tableau tranche ces cas au jugement anatomique plutôt que
/// par fréquence d'apparition (peu fiable, cf. session du 2026-09-20).
private let muscleGroupOverrides: [String: String] = [
    "Biceps brachial": "Biceps",
    "Brachial": "Biceps",
    "Deltoïde antérieur": "Épaules",
    "Deltoïde postérieur": "Épaules",
    "Fessiers": "Jambes",
    "Grand dorsal": "Dos",
    "Grand pectoral claviculaire": "Pectoraux",
    "Grand pectoral sternal": "Pectoraux",
    "Ischio-jambiers": "Jambes",
    "Lombaires": "Dos",
    "Quadriceps": "Jambes",
    "Rhomboïdes": "Dos",
    "Trapèzes": "Dos",
    "Trapèzes supérieurs": "Dos",
    "Triceps brachial": "Triceps"
]

/// Écran de sélection multiple de muscles, regroupés par groupe musculaire (même pattern que
/// `QualitySelectionView` pour les qualités de cycle, avec des sections en plus).
struct MuscleSelectionView: View {
    let title: String
    /// Chaque muscle avec le(s) groupe(s) où il apparaît dans la bibliothèque — utilisé pour le
    /// classer (override si ambigu, sinon le seul groupe trouvé).
    let musclesWithGroups: [(muscle: String, groups: Set<String>)]
    @Binding var selection: Set<String>

    private var groupedMuscles: [(group: String, muscles: [String])] {
        var byGroup: [String: [String]] = [:]
        for entry in musclesWithGroups {
            let group = muscleGroupOverrides[entry.muscle] ?? entry.groups.first ?? "Autre"
            byGroup[group, default: []].append(entry.muscle)
        }
        return MuscleGroupStyle.order.compactMap { group in
            guard let muscles = byGroup[group] else { return nil }
            return (group, muscles.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        }
    }

    var body: some View {
        List {
            ForEach(groupedMuscles, id: \.group) { entry in
                Section(entry.group) {
                    ForEach(entry.muscles, id: \.self) { muscle in
                        Button {
                            if selection.contains(muscle) {
                                selection.remove(muscle)
                            } else {
                                selection.insert(muscle)
                            }
                        } label: {
                            HStack {
                                Text(muscle)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                if selection.contains(muscle) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
