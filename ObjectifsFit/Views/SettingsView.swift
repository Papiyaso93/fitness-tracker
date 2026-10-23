import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query(sort: \ExerciseDefinition.name) private var exercises: [ExerciseDefinition]
    @Query private var reminders: [Reminder]

    @State private var showingAddReminder = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    SectionGroup {
                        SectionLabel(text: "Exercices")
                        NavigationLink {
                            ExerciseLibraryView()
                        } label: {
                            AppCard {
                                HStack {
                                    Text("Gérer les exercices")
                                        .font(.app(size: 15))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Text("\(exercises.count)")
                                        .font(.app(size: 13))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Image(systemName: "chevron.right")
                                        .font(.app(size: 12))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    SectionGroup {
                        HStack {
                            SectionLabel(text: "Rappels")
                            Spacer()
                            Button {
                                showingAddReminder = true
                            } label: {
                                AddPill(filled: false)
                            }
                            .padding(.trailing, 4)
                        }
                        if reminders.isEmpty {
                            AppCard {
                                Text("Aucun rappel")
                                    .font(.app(size: 14))
                                    .foregroundStyle(AppTheme.textSecondary)
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
                                                        .font(.app(size: 15, weight: .medium))
                                                        .foregroundStyle(AppTheme.textPrimary)
                                                    Text("\(reminder.scheduleLabel) · \(reminder.message)")
                                                        .font(.app(size: 12))
                                                        .foregroundStyle(AppTheme.textSecondary)
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.app(size: 12))
                                                    .foregroundStyle(AppTheme.textSecondary)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    SectionGroup {
                        SectionLabel(text: "Données")
                        NavigationLink {
                            ImportHistoryView()
                        } label: {
                            AppCard {
                                HStack {
                                    Text("Import et sauvegarde")
                                        .font(.app(size: 15))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.app(size: 12))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
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
