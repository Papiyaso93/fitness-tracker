import SwiftUI
import SwiftData

/// Sélecteur d'un jour de la semaine (un seul), 7 pastilles L-M-M-J-V-S-D — utilisé pour les
/// rappels hebdomadaires, partagé entre création et édition.
struct WeekdayPickerRow: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.ordered, id: \.weekday) { item in
                let isSelected = selection == item.weekday
                Button {
                    selection = item.weekday
                } label: {
                    Text(String(item.label.prefix(1)))
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
                        .background(isSelected ? AppTheme.accent : Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(isSelected ? AppTheme.accent : AppTheme.border, lineWidth: isSelected ? 0 : 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Création d'un rappel local paramétrable (nom, fréquence, heure, message).
struct AddReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title: String = ""
    @State private var message: String = ""
    @State private var time: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: .now) ?? .now
    @State private var frequency: ReminderFrequency = .quotidien
    @State private var weekday: Int = Calendar.current.component(.weekday, from: .now)

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
                    AppSegmentedControl(options: ReminderFrequency.allCases.map { ($0, $0.rawValue) }, selection: $frequency)
                        .listRowInsets(EdgeInsets())
                        .padding(4)
                    if frequency == .hebdomadaire {
                        WeekdayPickerRow(selection: $weekday)
                            .padding(.top, 4)
                    }
                } header: { formSectionHeader("Fréquence", required: true) }

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
            minute: components.minute ?? 0,
            frequency: frequency,
            weekday: frequency == .hebdomadaire ? weekday : nil
        )
        context.insert(reminder)
        NotificationManager.schedule(reminder)
        dismiss()
    }
}
