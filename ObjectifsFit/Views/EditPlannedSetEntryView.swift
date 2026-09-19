import SwiftUI
import SwiftData

struct EditPlannedSetEntryView: View {
    @Bindable var entry: PlannedSetEntry

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var weightText: String = ""
    @State private var bodyWeightText: String = ""
    @State private var repsText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Groupe musculaire") { MuscleGroupTag(group: entry.muscleGroup) }
                    LabeledContent("Exercice") { Text(entry.exerciseName) }
                    LabeledContent("Mode de résistance") { Text(entry.resistanceMode.rawValue) }
                } header: { formSectionHeader("Exercice") }

                Section {
                    switch entry.resistanceMode {
                    case .poidsLibre, .machine:
                        LabeledContent("Poids (kg)") {
                            TextField("0", text: $weightText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                    case .poidsDuCorps:
                        LabeledContent("Poids corps (kg)") {
                            TextField("0", text: $bodyWeightText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                    case .leste:
                        LabeledContent("Poids corps (kg)") {
                            TextField("0", text: $bodyWeightText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Lest ajouté (kg)") {
                            TextField("0", text: $weightText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                    case .elastique:
                        LabeledContent("Résistance (kg)") {
                            TextField("0", text: $weightText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                    }

                    LabeledContent {
                        TextField("0", text: $repsText).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    } label: {
                        fieldLabel("Répétitions", required: true)
                    }

                    AppMenuField(
                        label: "Sensation",
                        options: SensationLevel.allCases.map { ($0, $0.label) },
                        selection: $entry.sensation,
                        required: true
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        fieldCaption("Commentaire")
                        TextField("Optionnel", text: Binding(
                            get: { entry.comment ?? "" },
                            set: { entry.comment = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                    }

                    LabeledContent("Horodatage") {
                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                    }
                } header: { formSectionHeader("Série") }

                Section {
                    Button("Supprimer cette série", role: .destructive) {
                        context.delete(entry)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Modifier la série")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(Int(repsText) == nil)
                }
            }
            .onAppear {
                weightText = entry.weight.map { String(format: "%.1f", $0) } ?? ""
                bodyWeightText = entry.bodyWeight.map { String(format: "%.1f", $0) } ?? ""
                repsText = String(entry.reps)
            }
        }
    }

    private func save() {
        guard let repsValue = Int(repsText) else { return }
        entry.reps = repsValue
        switch entry.resistanceMode {
        case .poidsLibre, .machine:
            entry.weight = Double(weightText)
        case .poidsDuCorps:
            entry.bodyWeight = Double(bodyWeightText)
        case .leste:
            entry.weight = Double(weightText)
            entry.bodyWeight = Double(bodyWeightText)
        case .elastique:
            entry.weight = Double(weightText)
        }
        dismiss()
    }
}
