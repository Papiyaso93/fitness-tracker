import SwiftUI
import SwiftData

struct MealDetailView: View {
    @Bindable var meal: MealLog

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Heure") {
                DatePicker("Heure", selection: $meal.dateTime, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
            Section("Titre") {
                TextField("Titre", text: $meal.title)
            }
            Section("Description") {
                TextField("Description", text: $meal.mealDescription, axis: .vertical)
            }
            Section("Sensation") {
                Picker(selection: $meal.sensation) {
                    ForEach(MealSensation.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                } label: {
                    Text("Sensation")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section {
                Button("Supprimer ce repas", role: .destructive) {
                    context.delete(meal)
                    dismiss()
                }
            }
        }
        .navigationTitle("Repas")
        .navigationBarTitleDisplayMode(.inline)
    }
}
