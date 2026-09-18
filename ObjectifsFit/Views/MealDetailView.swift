import SwiftUI
import SwiftData

struct MealDetailView: View {
    @Bindable var meal: MealLog

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                DatePicker("Heure", selection: $meal.dateTime, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            } header: { formSectionHeader("Heure", required: true) }
            Section {
                TextField("Titre", text: $meal.title)
            } header: { formSectionHeader("Titre", required: true) }
            Section {
                TextField("Description", text: $meal.mealDescription, axis: .vertical)
            } header: { formSectionHeader("Description") }
            Section {
                MealSensationField(selection: $meal.sensation)
            } header: { formSectionHeader("Sensation", required: true) }
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
