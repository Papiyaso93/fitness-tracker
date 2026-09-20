import SwiftUI
import SwiftData

/// Édition d'un rappel existant — édition en direct + suppression, même pattern que
/// Repas/Transit/Sommeil.
struct EditReminderView: View {
    @Bindable var reminder: Reminder

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var time: Date

    init(reminder: Reminder) {
        self.reminder = reminder
        _time = State(initialValue: Calendar.current.date(bySettingHour: reminder.hour, minute: reminder.minute, second: 0, of: .now) ?? .now)
    }

    var body: some View {
        Form {
            Section {
                TextField("Nom", text: $reminder.title)
            } header: { formSectionHeader("Nom", required: true) }

            Section {
                DatePicker(selection: $time, displayedComponents: [.hourAndMinute]) {
                    fieldLabel("Heure")
                }
                .onChange(of: time) { _, newValue in
                    let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    reminder.hour = components.hour ?? reminder.hour
                    reminder.minute = components.minute ?? reminder.minute
                    NotificationManager.schedule(reminder)
                }
            } header: { formSectionHeader("Heure", required: true) }

            Section {
                TextField("Message", text: $reminder.message, axis: .vertical)
            } header: { formSectionHeader("Message", required: true) }

            Section {
                Button("Supprimer ce rappel", role: .destructive) {
                    NotificationManager.cancel(reminder)
                    context.delete(reminder)
                    dismiss()
                }
            }
        }
        .navigationTitle("Rappel")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: reminder.title) { _, _ in NotificationManager.schedule(reminder) }
        .onChange(of: reminder.message) { _, _ in NotificationManager.schedule(reminder) }
    }
}
