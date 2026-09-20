import SwiftUI
import SwiftData

/// Création d'un rappel local paramétrable (nom, heure, message).
struct AddReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title: String = ""
    @State private var message: String = ""
    @State private var time: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: .now) ?? .now

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !message.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ex: Transit, Sommeil, Étirements", text: $title)
                } header: { formSectionHeader("Nom", required: true) }

                Section {
                    DatePicker(selection: $time, displayedComponents: [.hourAndMinute]) {
                        fieldLabel("Heure")
                    }
                } header: { formSectionHeader("Heure", required: true) }

                Section {
                    TextField("Message affiché dans la notification", text: $message, axis: .vertical)
                } header: { formSectionHeader("Message", required: true) }
            }
            .navigationTitle("Nouveau rappel")
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

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let reminder = Reminder(
            title: title.trimmingCharacters(in: .whitespaces),
            message: message.trimmingCharacters(in: .whitespaces),
            hour: components.hour ?? 21,
            minute: components.minute ?? 0
        )
        context.insert(reminder)
        NotificationManager.schedule(reminder)
        dismiss()
    }
}
