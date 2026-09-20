import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query(sort: \ExerciseDefinition.name) private var exercises: [ExerciseDefinition]
    @Query private var reminders: [Reminder]

    @State private var showingAddReminder = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionLabel(text: "Exercices")
                    NavigationLink {
                        ExerciseLibraryView()
                    } label: {
                        AppCard {
                            HStack {
                                Text("Gérer les exercices")
                                    .font(.system(size: 15))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Text("\(exercises.count)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    HStack {
                        SectionLabel(text: "Rappels")
                        Spacer()
                        if !reminders.isEmpty {
                            Button {
                                showingAddReminder = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .padding(.trailing, 4)
                        }
                    }
                    if reminders.isEmpty {
                        AppCard {
                            Button {
                                showingAddReminder = true
                            } label: {
                                HStack {
                                    Text("Ajouter un rappel")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        VStack(spacing: 10) {
                            ForEach(reminders.sorted { $0.hour == $1.hour ? $0.minute < $1.minute : $0.hour < $1.hour }) { reminder in
                                NavigationLink {
                                    EditReminderView(reminder: reminder)
                                } label: {
                                    AppCard {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(reminder.title)
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundStyle(AppTheme.textPrimary)
                                                Text("\(reminder.timeLabel) · \(reminder.message)")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(AppTheme.textSecondary)
                                                    .lineLimit(1)
                                            }
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
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("Réglages")
            .sheet(isPresented: $showingAddReminder) {
                AddReminderView()
            }
            .task {
                await NotificationManager.requestAuthorization()
            }
        }
    }
}
