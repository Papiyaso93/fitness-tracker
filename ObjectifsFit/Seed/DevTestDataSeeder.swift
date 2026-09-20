import Foundation
import SwiftData

/// Génère un historique d'entraînement réaliste (programme + 4 cycles + séances loguées sur ~16
/// semaines) pour visualiser les graphes du Tableau de bord avec de la vraie densité de données.
/// Outil de développement uniquement, déclenché depuis Réglages — n'est jamais appelé au premier
/// lancement (voir `SeedData` pour la bibliothèque d'exercices, qui elle est un vrai contenu appli).
enum DevTestDataSeeder {
    private struct ExercisePick {
        let name: String
        let muscleGroup: String
        let resistanceMode: ResistanceMode
        let baseWeight: Double?
    }

    private struct CyclePlan {
        let name: String
        let weeksAgo: Int
        let durationWeeks: Int
        let principal: [PhysicalQuality]
    }

    private static let pushExercises = [
        ExercisePick(name: "Développé couché haltères", muscleGroup: "Pectoraux", resistanceMode: .poidsLibre, baseWeight: 24),
        ExercisePick(name: "Développé militaire", muscleGroup: "Épaules", resistanceMode: .poidsLibre, baseWeight: 14),
        ExercisePick(name: "Élévations latérales", muscleGroup: "Épaules", resistanceMode: .poidsLibre, baseWeight: 8),
        ExercisePick(name: "Triceps poulie haute (vertical)", muscleGroup: "Triceps", resistanceMode: .machine, baseWeight: 20)
    ]

    private static let pullExercises = [
        ExercisePick(name: "Tirage horizontal", muscleGroup: "Dos", resistanceMode: .machine, baseWeight: 45),
        ExercisePick(name: "Tractions", muscleGroup: "Dos", resistanceMode: .poidsDuCorps, baseWeight: nil),
        ExercisePick(name: "Curl haltères", muscleGroup: "Biceps", resistanceMode: .poidsLibre, baseWeight: 10),
        ExercisePick(name: "Crunch à la poulie haute", muscleGroup: "Abdos", resistanceMode: .machine, baseWeight: 25)
    ]

    private static let legsExercises = [
        ExercisePick(name: "Squat", muscleGroup: "Jambes", resistanceMode: .poidsLibre, baseWeight: 40),
        ExercisePick(name: "Presse horizontale", muscleGroup: "Jambes", resistanceMode: .machine, baseWeight: 80),
        ExercisePick(name: "Leg curl", muscleGroup: "Jambes", resistanceMode: .machine, baseWeight: 30),
        ExercisePick(name: "Extension mollet debout", muscleGroup: "Jambes", resistanceMode: .machine, baseWeight: 40)
    ]

    private static let cyclePlans = [
        CyclePlan(name: "Cycle 1 — Fondations", weeksAgo: 16, durationWeeks: 4, principal: [.hypertrophie]),
        CyclePlan(name: "Cycle 2 — Volume", weeksAgo: 12, durationWeeks: 4, principal: [.hypertrophie, .enduranceAerobie]),
        CyclePlan(name: "Cycle 3 — Intensité", weeksAgo: 8, durationWeeks: 4, principal: [.force]),
        CyclePlan(name: "Cycle 4 — Affûtage", weeksAgo: 4, durationWeeks: 4, principal: [.vo2max, .maintien])
    ]

    private static let programTitle = "Recomposition corporelle"

    /// N'ajoute rien si le programme de test existe déjà — évite les doublons si le bouton est
    /// pressé plusieurs fois.
    static func seedRealisticTrainingHistory(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<TrainingProgram>(predicate: #Predicate { $0.title == programTitle }))) ?? []
        guard existing.isEmpty else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let program = TrainingProgram(
            title: programTitle,
            programDescription: "Perte de masse grasse en préservant le muscle, amélioration du cardio.",
            startDate: calendar.date(byAdding: .weekOfYear, value: -16, to: today),
            status: .enCours
        )
        context.insert(program)

        let masseGrasse = ProgramObjective(category: .principal, isMeasurable: true, metricType: .masseGrasse, mode: .progression, startValue: 20, targetValue: 15, order: 0)
        masseGrasse.program = program
        context.insert(masseGrasse)

        let vo2max = ProgramObjective(category: .principal, isMeasurable: true, metricType: .vo2max, mode: .progression, startValue: 51, targetValue: 57, order: 1)
        vo2max.program = program
        context.insert(vo2max)

        var globalWeekIndex = 0

        for plan in cyclePlans {
            guard let cycleStart = calendar.date(byAdding: .weekOfYear, value: -plan.weeksAgo, to: today),
                  let cycleEnd = calendar.date(byAdding: .weekOfYear, value: plan.durationWeeks, to: cycleStart) else { continue }

            let cycle = Cycle(
                name: plan.name,
                startDate: cycleStart,
                endDate: cycleEnd,
                type: .standard,
                isActive: cycleEnd > today,
                program: program,
                objectifsPrincipaux: plan.principal
            )
            context.insert(cycle)

            for weekInCycle in 1...plan.durationWeeks {
                globalWeekIndex += 1
                let progression = Double(globalWeekIndex) * 0.6

                addMusculationSession(title: "Push", weekday: 3, weekNumber: weekInCycle, cycle: cycle, exercises: pushExercises, progression: progression, skip: shouldSkip(week: globalWeekIndex, day: 3), context: context, calendar: calendar)
                addCardioSession(title: "Fractionné", weekday: 4, weekNumber: weekInCycle, cycle: cycle, skip: shouldSkip(week: globalWeekIndex, day: 4), context: context, calendar: calendar)
                addMusculationSession(title: "Pull", weekday: 5, weekNumber: weekInCycle, cycle: cycle, exercises: pullExercises, progression: progression, skip: shouldSkip(week: globalWeekIndex, day: 5), context: context, calendar: calendar)
                addMusculationSession(title: "Jambes", weekday: 7, weekNumber: weekInCycle, cycle: cycle, exercises: legsExercises, progression: progression, skip: shouldSkip(week: globalWeekIndex, day: 7), context: context, calendar: calendar)
                addCardioSession(title: "Endurance fondamentale", weekday: 1, weekNumber: weekInCycle, cycle: cycle, skip: shouldSkip(week: globalWeekIndex, day: 1), context: context, calendar: calendar)
            }
        }
    }

    /// Motif de séances manquées déterministe (~11%) — pour un historique crédible plutôt qu'une
    /// assiduité parfaite à 100%.
    private static func shouldSkip(week: Int, day: Int) -> Bool {
        (week * 7 + day) % 9 == 0
    }

    private static func addMusculationSession(title: String, weekday: Int, weekNumber: Int, cycle: Cycle, exercises: [ExercisePick], progression: Double, skip: Bool, context: ModelContext, calendar: Calendar) {
        let session = CycleSession(weekNumber: weekNumber, weekday: weekday, title: title, kind: .musculation, objective: .hypertrophie, order: 0)
        session.cycle = cycle
        context.insert(session)

        for (index, pick) in exercises.enumerated() {
            let planned = PlannedExercise(muscleGroup: pick.muscleGroup, exerciseName: pick.name, resistanceMode: pick.resistanceMode, targetSets: 3, targetWeight: pick.baseWeight, isRepsRange: true, targetRepsMin: 8, targetRepsMax: 12, order: index)
            planned.session = session
            context.insert(planned)
        }

        guard !skip, let scheduledDate = session.scheduledDate, scheduledDate <= .now else { return }

        let completion = SessionCompletion(startTime: scheduledDate, endTime: calendar.date(byAdding: .minute, value: 55, to: scheduledDate))
        completion.cycleSession = session
        context.insert(completion)

        let sensations: [SensationLevel] = [.confortable, .normal, .difficile]
        for pick in exercises {
            for setIndex in 0..<3 {
                let reps = 12 - setIndex * 2
                let weight = pick.baseWeight.map { $0 + progression }
                let entry = PlannedSetEntry(
                    date: scheduledDate,
                    exerciseName: pick.name,
                    muscleGroup: pick.muscleGroup,
                    resistanceMode: pick.resistanceMode,
                    weight: weight,
                    reps: reps,
                    sensation: sensations[min(setIndex, sensations.count - 1)]
                )
                entry.completion = completion
                context.insert(entry)
            }
        }
    }

    private static func addCardioSession(title: String, weekday: Int, weekNumber: Int, cycle: Cycle, skip: Bool, context: ModelContext, calendar: Calendar) {
        let session = CycleSession(weekNumber: weekNumber, weekday: weekday, title: title, kind: .autre, objective: .enduranceAerobie, sessionDescription: title, order: 1)
        session.cycle = cycle
        context.insert(session)

        guard !skip, let scheduledDate = session.scheduledDate, scheduledDate <= .now else { return }

        let completion = SessionCompletion(startTime: scheduledDate, endTime: calendar.date(byAdding: .minute, value: 40, to: scheduledDate), planApplied: true)
        completion.cycleSession = session
        context.insert(completion)
    }
}
