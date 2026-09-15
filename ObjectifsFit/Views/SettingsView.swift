import SwiftUI

struct SettingsView: View {
    @AppStorage("transitReminderHour") private var transitReminderHour = 21
    @StateObject private var healthKit = HealthKitManager()
    @State private var healthKitStatus = "Non demandée"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionLabel(text: "Rappel transit")
                    AppCard {
                        Stepper("Heure du rappel : \(transitReminderHour)h", value: $transitReminderHour, in: 18...23)
                            .foregroundStyle(AppTheme.textPrimary)
                            .onChange(of: transitReminderHour) { _, newValue in
                                NotificationManager.scheduleTransitReminder(hour: newValue)
                            }
                    }

                    SectionLabel(text: "Apple Santé")
                    AppCard {
                        Text("Statut : \(healthKitStatus)")
                            .foregroundStyle(AppTheme.textPrimary)
                        Button("Autoriser l'accès à Santé") {
                            Task {
                                try? await healthKit.requestAuthorization()
                                healthKitStatus = "Autorisation demandée"
                            }
                        }
                        .foregroundStyle(AppTheme.accent)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("Réglages")
            .task {
                await NotificationManager.requestAuthorization()
            }
        }
    }
}
