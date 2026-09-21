import Foundation
import SwiftData

/// Restaure un export "Bilan coach" (JSON produit par `BilanExportBuilder`) — pensé pour le
/// changement d'appareil : recrée programmes/cycles/séances/séries/repas/transit/sommeil/mesures
/// depuis une sauvegarde, sans jamais dupliquer si le même fichier est réimporté (idempotent, par
/// id pour les entités qui en ont un, par signature de contenu pour les autres).
enum BilanRestoreImporter {

    struct RestoreResult {
        var restoredPrograms = 0
        var restoredCycles = 0
        var restoredSessions = 0
        var restoredSetEntries = 0
        var restoredMeals = 0
        var restoredTransitLogs = 0
        var restoredSleepLogs = 0
        var restoredMetricEntries = 0
        var skippedExisting = 0
    }

    enum RestoreError: Error {
        case cannotReadFile
    }

    static func restore(url: URL, context: ModelContext) throws -> RestoreResult {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { throw RestoreError.cannotReadFile }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BilanExportPayload.self, from: data)

        var result = RestoreResult()

        var programsById = Dictionary(uniqueKeysWithValues: (try? context.fetch(FetchDescriptor<TrainingProgram>()))?.map { ($0.id, $0) } ?? [])
        var cyclesById = Dictionary(uniqueKeysWithValues: (try? context.fetch(FetchDescriptor<Cycle>()))?.map { ($0.id, $0) } ?? [])
        let existingSessionIds = Set((try? context.fetch(FetchDescriptor<CycleSession>()))?.map(\.id) ?? [])

        // Programmes
        for dto in payload.programs where programsById[dto.id] == nil {
            let program = TrainingProgram(
                title: dto.title,
                programDescription: dto.programDescription,
                startDate: dto.startDate,
                endDate: dto.endDate,
                status: ProgramStatus(rawValue: dto.status) ?? .enCours
            )
            program.id = dto.id
            context.insert(program)
            for (index, objective) in dto.principalObjectives.enumerated() {
                context.insert(makeObjective(objective, category: .principal, order: index, program: program))
            }
            for (index, objective) in dto.secondaryObjectives.enumerated() {
                context.insert(makeObjective(objective, category: .indicateur, order: index, program: program))
            }
            programsById[dto.id] = program
            result.restoredPrograms += 1
        }

        // Cycles
        for dto in payload.cycles where cyclesById[dto.id] == nil {
            let cycle = Cycle(
                name: dto.name,
                startDate: dto.startDate,
                endDate: dto.endDate,
                type: CycleType(rawValue: dto.type) ?? .standard,
                isActive: dto.isActive,
                notes: dto.notes,
                program: dto.programId.flatMap { programsById[$0] },
                objectifsPrincipaux: dto.objectifsPrincipaux.compactMap(PhysicalQuality.init(rawValue:)),
                objectifsSecondaires: dto.objectifsSecondaires.compactMap(PhysicalQuality.init(rawValue:))
            )
            cycle.id = dto.id
            context.insert(cycle)
            for (index, objective) in dto.objectives.enumerated() {
                context.insert(makeObjective(objective, category: .principal, order: index, cycle: cycle))
            }
            cyclesById[dto.id] = cycle
            result.restoredCycles += 1
        }

        // Séances (avec exercices planifiés + complétion + séries)
        for dto in payload.cycleSessions {
            guard !existingSessionIds.contains(dto.id) else {
                result.skippedExisting += 1
                continue
            }
            let session = CycleSession(
                weekNumber: dto.weekNumber,
                weekday: dto.weekday,
                title: dto.title,
                kind: SessionKind(rawValue: dto.kind) ?? .autre,
                objective: dto.objective.flatMap(PhysicalQuality.init(rawValue:)),
                sessionDescription: dto.sessionDescription,
                isAdHoc: dto.isAdHoc,
                adHocDate: dto.isAdHoc ? dto.scheduledDate : nil
            )
            session.id = dto.id
            session.cycle = dto.cycleId.flatMap { cyclesById[$0] }
            context.insert(session)

            for (index, exerciseDTO) in dto.exercises.enumerated() {
                let exercise = PlannedExercise(
                    muscleGroup: exerciseDTO.muscleGroup,
                    exerciseName: exerciseDTO.exerciseName,
                    technique: SetTechnique(rawValue: exerciseDTO.technique) ?? .normal,
                    resistanceMode: ResistanceMode(rawValue: exerciseDTO.resistanceMode) ?? .poidsLibre,
                    targetSets: exerciseDTO.targetSets,
                    targetWeight: exerciseDTO.targetWeight,
                    isRepsRange: exerciseDTO.isRepsRange,
                    targetRepsMin: exerciseDTO.targetRepsMin,
                    targetRepsMax: exerciseDTO.targetRepsMax,
                    order: index
                )
                exercise.session = session
                context.insert(exercise)
            }

            if let completionDTO = dto.completion {
                let completion = SessionCompletion(
                    startTime: completionDTO.startTime,
                    endTime: completionDTO.endTime,
                    simpleComment: completionDTO.simpleComment,
                    planApplied: completionDTO.planApplied,
                    isAdapted: completionDTO.isAdapted,
                    adaptedTitle: completionDTO.adaptedTitle,
                    adaptedKind: completionDTO.adaptedKind.flatMap(SessionKind.init(rawValue:))
                )
                completion.cycleSession = session
                context.insert(completion)
                for entryDTO in completionDTO.setEntries {
                    let entry = makeSetEntry(entryDTO)
                    entry.completion = completion
                    context.insert(entry)
                    result.restoredSetEntries += 1
                }
            }
            result.restoredSessions += 1
        }

        // Séries orphelines (historique importé, hors séance planifiée)
        let existingOrphanSignatures = Set(
            ((try? context.fetch(FetchDescriptor<PlannedSetEntry>())) ?? [])
                .filter { $0.completion == nil }
                .map(\.dedupSignature)
        )
        var seenSignatures = existingOrphanSignatures
        for entryDTO in payload.orphanSetEntries {
            let sig = PlannedSetEntry.dedupSignature(date: entryDTO.date, exerciseName: entryDTO.exerciseName, reps: entryDTO.reps, weight: entryDTO.weight)
            guard !seenSignatures.contains(sig) else {
                result.skippedExisting += 1
                continue
            }
            seenSignatures.insert(sig)
            context.insert(makeSetEntry(entryDTO))
            result.restoredSetEntries += 1
        }

        // Repas
        let existingMealSignatures = Set(((try? context.fetch(FetchDescriptor<MealLog>())) ?? []).map { "\($0.dateTime.timeIntervalSince1970)|\($0.title)" })
        for dto in payload.meals {
            let sig = "\(dto.dateTime.timeIntervalSince1970)|\(dto.title)"
            guard !existingMealSignatures.contains(sig) else {
                result.skippedExisting += 1
                continue
            }
            context.insert(MealLog(dateTime: dto.dateTime, title: dto.title, mealDescription: dto.mealDescription, sensation: MealSensation(rawValue: dto.sensation) ?? .rassasiePile))
            result.restoredMeals += 1
        }

        // Transit
        let existingTransitSignatures = Set(((try? context.fetch(FetchDescriptor<TransitLog>())) ?? []).map(\.dateTime.timeIntervalSince1970))
        for dto in payload.transitLogs {
            guard !existingTransitSignatures.contains(dto.dateTime.timeIntervalSince1970) else {
                result.skippedExisting += 1
                continue
            }
            context.insert(TransitLog(dateTime: dto.dateTime, bristolType: BristolType(rawValue: dto.bristolType) ?? .type4))
            result.restoredTransitLogs += 1
        }

        // Sommeil — un enregistrement par jour, clé = jour
        let existingSleepDays = Set(((try? context.fetch(FetchDescriptor<SleepLog>())) ?? []).map(\.day.timeIntervalSince1970))
        for dto in payload.sleepLogs {
            guard !existingSleepDays.contains(dto.day.timeIntervalSince1970) else {
                result.skippedExisting += 1
                continue
            }
            let log = SleepLog(day: dto.day)
            log.wakeTime = dto.wakeTime
            log.wakeEnergy = dto.wakeEnergy.flatMap(EnergyLevel.init(rawValue:))
            log.wakeStomach = dto.wakeStomach.flatMap(StomachState.init(rawValue:))
            log.bedTime = dto.bedTime
            log.bedEnergy = dto.bedEnergy.flatMap(EnergyLevel.init(rawValue:))
            log.bedStomach = dto.bedStomach.flatMap(StomachState.init(rawValue:))
            context.insert(log)
            result.restoredSleepLogs += 1
        }

        // Mesures (masse grasse / poids / VO2max)
        let existingMetricSignatures = Set(((try? context.fetch(FetchDescriptor<MetricEntry>())) ?? []).map { "\($0.type.rawValue)|\($0.date.timeIntervalSince1970)" })
        for dto in payload.metricEntries {
            let sig = "\(dto.type)|\(dto.date.timeIntervalSince1970)"
            guard !existingMetricSignatures.contains(sig) else {
                result.skippedExisting += 1
                continue
            }
            guard let type = HeadlineGoalType(rawValue: dto.type) else { continue }
            context.insert(MetricEntry(type: type, value: dto.value, date: dto.date, source: MetricSource(rawValue: dto.source) ?? .manual))
            result.restoredMetricEntries += 1
        }

        return result
    }

    private static func makeObjective(_ dto: ObjectiveDTO, category: ObjectiveCategory, order: Int, program: TrainingProgram? = nil, cycle: Cycle? = nil) -> ProgramObjective {
        let objective = ProgramObjective(
            category: category,
            isMeasurable: dto.isMeasurable,
            freeText: dto.freeText,
            metricType: dto.metricType.flatMap(ObjectiveMetricType.init(rawValue:)),
            customMetricName: dto.customMetricName,
            customUnit: dto.customUnit,
            mode: dto.mode.flatMap(ObjectiveMode.init(rawValue:)),
            startValue: dto.startValue,
            targetValue: dto.targetValue,
            order: order
        )
        objective.program = program
        objective.cycle = cycle
        return objective
    }

    private static func makeSetEntry(_ dto: SetEntryDTO) -> PlannedSetEntry {
        PlannedSetEntry(
            date: dto.date,
            exerciseName: dto.exerciseName,
            muscleGroup: dto.muscleGroup,
            resistanceMode: ResistanceMode(rawValue: dto.resistanceMode) ?? .poidsLibre,
            weight: dto.weight,
            bodyWeight: dto.bodyWeight,
            reps: dto.reps,
            sensation: SensationLevel.fromLabel(dto.sensation) ?? .normal,
            comment: dto.comment,
            coefficient: dto.coefficient,
            technique: SetTechnique(rawValue: dto.technique) ?? .normal,
            techniqueOtherLabel: dto.techniqueOtherLabel
        )
    }
}
