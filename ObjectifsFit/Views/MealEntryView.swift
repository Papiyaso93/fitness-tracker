import SwiftUI
import SwiftData

struct MealEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var dateTime = Date.now
    @State private var title = ""
    @State private var description = ""
    @State private var sensation: MealSensation = .rassasie80

    var body: some View {
        NavigationStack {
            Form {
                Section("Heure") {
                    DatePicker("Heure", selection: $dateTime, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
                Section("Titre") {
                    TextField("Ex: Déjeuner, Dîner, Collation", text: $title)
                }
                Section("Description") {
                    TextField("Qu'as-tu mangé ?", text: $description, axis: .vertical)
                }
                Section("Sensation") {
                    Picker(selection: $sensation) {
                        ForEach(MealSensation.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    } label: {
                        Text("Sensation")
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Nouveau repas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let meal = MealLog(dateTime: dateTime, title: title, mealDescription: description, sensation: sensation)
                        context.insert(meal)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
