import SwiftUI
import SwiftData

@main
struct ObjectifsFitApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            Cycle.self,
            TrainingProgram.self,
            ProgramObjective.self,
            CycleSession.self,
            PlannedExercise.self,
            SessionCompletion.self,
            PlannedSetEntry.self,
            MetricEntry.self,
            ExerciseDefinition.self,
            MealLog.self,
            TransitLog.self,
            SleepLog.self,
            Reminder.self,
            ArchivedBilan.self
        ])
        // TODO: réactiver cloudKitDatabase: .automatic une fois tous les champs des modèles
        // dotés de valeurs par défaut (CloudKit l'exige pour attributs et relations).
        let configuration = ModelConfiguration(schema: schema)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Impossible d'initialiser SwiftData : \(error)")
        }

        SeedData.seedExerciseLibraryIfNeeded(context: container.mainContext)
        SeedData.seedDefaultRemindersIfNeeded(context: container.mainContext)
        let reminders = (try? container.mainContext.fetch(FetchDescriptor<Reminder>())) ?? []
        NotificationManager.syncPending(with: reminders)
        AppAppearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .tint(AppTheme.accent)
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
