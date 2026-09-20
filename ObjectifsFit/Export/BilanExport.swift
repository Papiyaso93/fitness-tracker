import Foundation
import SwiftData

/// DTOs de l'export "Bilan coach" — miroir Codable des modèles SwiftData, en listes plates
/// reliées par id plutôt qu'en hiérarchie imbriquée, pour rester simple à construire depuis des
/// FetchDescriptor indépendants. Tout l'historique est exporté, sans filtre de date.
struct BilanExportPayload: Codable {
    var exportedAt: Date
    var programs: [ProgramDTO]
    var cycles: [CycleDTO]
    var cycleSessions: [CycleSessionDTO]
    var meals: [MealDTO]
    var transitLogs: [TransitDTO]
    var sleepLogs: [SleepDTO]
    var metricEntries: [MetricDTO]
}

struct ObjectiveDTO: Codable {
    var category: String
    var isMeasurable: Bool
    var freeText: String?
    var metricType: String?
    var customMetricName: String?
    var customUnit: String?
    var mode: String?
    var startValue: Double?
    var targetValue: Double?
    var summary: String
}

struct ProgramDTO: Codable {
    var id: UUID
    var title: String
    var programDescription: String?
    var startDate: Date?
    var endDate: Date?
    var status: String
    var principalObjectives: [ObjectiveDTO]
    var secondaryObjectives: [ObjectiveDTO]
}

struct CycleDTO: Codable {
    var id: UUID
    var programId: UUID?
    var name: String
    var startDate: Date
    var endDate: Date
    var type: String
    var isActive: Bool
    var status: String
    var notes: String?
    var objectifsPrincipaux: [String]
    var objectifsSecondaires: [String]
    var objectives: [ObjectiveDTO]
}

struct PlannedExerciseDTO: Codable {
    var muscleGroup: String
    var exerciseName: String
    var technique: String
    var resistanceMode: String
    var targetSets: Int
    var targetWeight: Double?
    var isRepsRange: Bool
    var targetRepsMin: Int
    var targetRepsMax: Int
}

struct SetEntryDTO: Codable {
    var date: Date
    var exerciseName: String
    var muscleGroup: String
    var resistanceMode: String
    var weight: Double?
    var bodyWeight: Double?
    var reps: Int
    var sensation: String
    var comment: String?
    var coefficient: Double
    var technique: String
    var techniqueOtherLabel: String?
    var tonnage: Double?
    var estimated1RM: Double?
}

struct SessionCompletionDTO: Codable {
    var startTime: Date?
    var endTime: Date?
    var simpleComment: String?
    var planApplied: Bool?
    var isAdapted: Bool
    var adaptedTitle: String?
    var adaptedKind: String?
    var setEntries: [SetEntryDTO]
}

struct CycleSessionDTO: Codable {
    var id: UUID
    var cycleId: UUID?
    var weekNumber: Int
    var weekday: Int
    var title: String
    var kind: String
    var objective: String?
    var sessionDescription: String?
    var isAdHoc: Bool
    var scheduledDate: Date?
    var exercises: [PlannedExerciseDTO]
    var completion: SessionCompletionDTO?
}

struct MealDTO: Codable {
    var dateTime: Date
    var title: String
    var mealDescription: String
    var sensation: String
}

struct TransitDTO: Codable {
    var dateTime: Date
    var bristolType: Int
    var bristolLabel: String
}

struct SleepDTO: Codable {
    var day: Date
    var wakeTime: Date?
    var wakeEnergy: String?
    var wakeStomach: String?
    var bedTime: Date?
    var bedEnergy: String?
    var bedStomach: String?
}

struct MetricDTO: Codable {
    var type: String
    var value: Double
    var date: Date
    var source: String
}

enum BilanExportBuilder {
    /// Construit l'export complet depuis SwiftData — tout l'historique, sans filtre de date.
    static func build(context: ModelContext) throws -> BilanExportPayload {
        let programs = try context.fetch(FetchDescriptor<TrainingProgram>())
        let cycles = try context.fetch(FetchDescriptor<Cycle>())
        let sessions = try context.fetch(FetchDescriptor<CycleSession>())
        let meals = try context.fetch(FetchDescriptor<MealLog>())
        let transitLogs = try context.fetch(FetchDescriptor<TransitLog>())
        let sleepLogs = try context.fetch(FetchDescriptor<SleepLog>())
        let metrics = try context.fetch(FetchDescriptor<MetricEntry>())

        return BilanExportPayload(
            exportedAt: .now,
            programs: programs.map(programDTO),
            cycles: cycles.map(cycleDTO),
            cycleSessions: sessions.map(cycleSessionDTO),
            meals: meals.map(mealDTO),
            transitLogs: transitLogs.map(transitDTO),
            sleepLogs: sleepLogs.map(sleepDTO),
            metricEntries: metrics.map(metricDTO)
        )
    }

    static func objectiveDTO(_ objective: ProgramObjective) -> ObjectiveDTO {
        ObjectiveDTO(
            category: objective.category.rawValue,
            isMeasurable: objective.isMeasurable,
            freeText: objective.freeText,
            metricType: objective.metricType?.rawValue,
            customMetricName: objective.customMetricName,
            customUnit: objective.customUnit,
            mode: objective.mode?.rawValue,
            startValue: objective.startValue,
            targetValue: objective.targetValue,
            summary: objective.summary
        )
    }

    static func programDTO(_ program: TrainingProgram) -> ProgramDTO {
        ProgramDTO(
            id: program.id,
            title: program.title,
            programDescription: program.programDescription,
            startDate: program.startDate,
            endDate: program.endDate,
            status: program.status.rawValue,
            principalObjectives: program.principalObjectives.map(objectiveDTO),
            secondaryObjectives: program.secondaryObjectives.map(objectiveDTO)
        )
    }

    static func cycleDTO(_ cycle: Cycle) -> CycleDTO {
        CycleDTO(
            id: cycle.id,
            programId: cycle.program?.id,
            name: cycle.name,
            startDate: cycle.startDate,
            endDate: cycle.endDate,
            type: cycle.type.rawValue,
            isActive: cycle.isActive,
            status: cycle.status.rawValue,
            notes: cycle.notes,
            objectifsPrincipaux: cycle.objectifsPrincipaux.map(\.rawValue),
            objectifsSecondaires: cycle.objectifsSecondaires.map(\.rawValue),
            objectives: cycle.sortedObjectives.map(objectiveDTO)
        )
    }

    static func plannedExerciseDTO(_ exercise: PlannedExercise) -> PlannedExerciseDTO {
        PlannedExerciseDTO(
            muscleGroup: exercise.muscleGroup,
            exerciseName: exercise.exerciseName,
            technique: exercise.technique.rawValue,
            resistanceMode: exercise.resistanceMode.rawValue,
            targetSets: exercise.targetSets,
            targetWeight: exercise.targetWeight,
            isRepsRange: exercise.isRepsRange,
            targetRepsMin: exercise.targetRepsMin,
            targetRepsMax: exercise.targetRepsMax
        )
    }

    static func setEntryDTO(_ entry: PlannedSetEntry) -> SetEntryDTO {
        SetEntryDTO(
            date: entry.date,
            exerciseName: entry.exerciseName,
            muscleGroup: entry.muscleGroup,
            resistanceMode: entry.resistanceMode.rawValue,
            weight: entry.weight,
            bodyWeight: entry.bodyWeight,
            reps: entry.reps,
            sensation: entry.sensation.label,
            comment: entry.comment,
            coefficient: entry.coefficient,
            technique: entry.technique.rawValue,
            techniqueOtherLabel: entry.techniqueOtherLabel,
            tonnage: entry.tonnage,
            estimated1RM: entry.estimated1RM
        )
    }

    static func cycleSessionDTO(_ session: CycleSession) -> CycleSessionDTO {
        let completion: SessionCompletionDTO? = session.completion.map { completion in
            SessionCompletionDTO(
                startTime: completion.startTime,
                endTime: completion.endTime,
                simpleComment: completion.simpleComment,
                planApplied: completion.planApplied,
                isAdapted: completion.isAdapted,
                adaptedTitle: completion.adaptedTitle,
                adaptedKind: completion.adaptedKind?.rawValue,
                setEntries: completion.setEntries.map(setEntryDTO)
            )
        }
        return CycleSessionDTO(
            id: session.id,
            cycleId: session.cycle?.id,
            weekNumber: session.weekNumber,
            weekday: session.weekday,
            title: session.title,
            kind: session.kind.rawValue,
            objective: session.objective?.rawValue,
            sessionDescription: session.sessionDescription,
            isAdHoc: session.isAdHoc,
            scheduledDate: session.scheduledDate,
            exercises: session.sortedExercises.map(plannedExerciseDTO),
            completion: completion
        )
    }

    static func mealDTO(_ meal: MealLog) -> MealDTO {
        MealDTO(dateTime: meal.dateTime, title: meal.title, mealDescription: meal.mealDescription, sensation: meal.sensation.rawValue)
    }

    static func transitDTO(_ log: TransitLog) -> TransitDTO {
        TransitDTO(dateTime: log.dateTime, bristolType: log.bristolType.rawValue, bristolLabel: log.bristolType.shortLabel)
    }

    static func sleepDTO(_ log: SleepLog) -> SleepDTO {
        SleepDTO(
            day: log.day,
            wakeTime: log.wakeTime,
            wakeEnergy: log.wakeEnergy?.rawValue,
            wakeStomach: log.wakeStomach?.rawValue,
            bedTime: log.bedTime,
            bedEnergy: log.bedEnergy?.rawValue,
            bedStomach: log.bedStomach?.rawValue
        )
    }

    static func metricDTO(_ entry: MetricEntry) -> MetricDTO {
        MetricDTO(type: entry.type.rawValue, value: entry.value, date: entry.date, source: entry.source.rawValue)
    }

    /// Encode en JSON lisible (indenté — n'a pas besoin d'être compact, personne ne le relit).
    static func encodeJSON(_ payload: BilanExportPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }
}
