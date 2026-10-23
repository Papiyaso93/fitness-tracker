import SwiftUI
import SwiftData

@main
struct ObjectifsFitApp: App {
    let container: ModelContainer
    @State private var toastCenter = ToastCenter()

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
            ArchivedBilan.self,
            BodyMeasurementEntry.self,
            WeeklyCheckIn.self
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
        SeedData.renamePlannedExerciseAliasesIfNeeded(context: container.mainContext)
        SeedData.seedDefaultRemindersIfNeeded(context: container.mainContext)
        let reminders = (try? container.mainContext.fetch(FetchDescriptor<Reminder>())) ?? []
        NotificationManager.syncPending(with: reminders)
        AppAppearance.apply()

        // Permet d'annuler une suppression depuis la pastille « Annuler » (voir `ToastCenter`).
        container.mainContext.undoManager = UndoManager()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .toastOverlay()
                .environment(toastCenter)
                .tint(AppTheme.accent)
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
