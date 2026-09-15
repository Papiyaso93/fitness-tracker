import Foundation
import SwiftData

enum SeedData {

    /// Programmes de test pour vérifier visuellement le rendu des cartes/tri/statuts sur
    /// "Programme bis" — temporaire, à supprimer une fois validé.
    static func seedTestProgramsIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<TrainingProgram>()
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func days(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today) ?? today }

        // 1) En cours, avec dates, plusieurs objectifs principaux + indicateurs.
        let perteDeGras = TrainingProgram(
            title: "Perte de gras",
            programDescription: "Retrouver de la masse grasse en préservant le muscle",
            startDate: days(-10),
            endDate: days(20)
        )
        context.insert(perteDeGras)
        let mg = ProgramObjective(category: .principal, isMeasurable: true, metricType: .masseGrasse, mode: .progression, startValue: 22, targetValue: 16, order: 0)
        mg.program = perteDeGras
        let vo2 = ProgramObjective(category: .principal, isMeasurable: true, metricType: .vo2max, mode: .progression, startValue: 38, targetValue: 44, order: 1)
        vo2.program = perteDeGras
        let poids = ProgramObjective(category: .indicateur, isMeasurable: true, metricType: .poids, mode: .progression, startValue: 82, targetValue: 76, order: 0)
        poids.program = perteDeGras
        for o in [mg, vo2, poids] { context.insert(o) }

        // 2) À venir, avec dates, un seul objectif principal (texte libre) + un indicateur chiffré.
        let marathon = TrainingProgram(
            title: "Préparation marathon",
            programDescription: "Bloc dédié après le retour du Japon",
            startDate: days(30),
            endDate: days(120)
        )
        context.insert(marathon)
        let objectifMarathon = ProgramObjective(category: .principal, isMeasurable: false, freeText: "Terminer un marathon", order: 0)
        objectifMarathon.program = marathon
        let pas = ProgramObjective(category: .indicateur, isMeasurable: true, metricType: .nombreDePas, mode: .progression, startValue: 5000, targetValue: 9000, order: 0)
        pas.program = marathon
        for o in [objectifMarathon, pas] { context.insert(o) }

        // 3) Terminé (dates passées), pour vérifier le statut déduit automatiquement.
        let reprise = TrainingProgram(
            title: "Reprise après pause",
            startDate: days(-90),
            endDate: days(-30)
        )
        context.insert(reprise)
        let objectifReprise = ProgramObjective(category: .principal, isMeasurable: false, freeText: "Retrouver ses sensations", order: 0)
        objectifReprise.program = reprise
        context.insert(objectifReprise)

        // 4) Sans dates du tout — vérifie l'affichage quand rien n'est renseigné.
        let sansDates = TrainingProgram(title: "Programme sans dates")
        context.insert(sansDates)
        let objectifSansDates = ProgramObjective(category: .principal, isMeasurable: false, freeText: "Tester l'app sans dates renseignées", order: 0)
        objectifSansDates.program = sansDates
        context.insert(objectifSansDates)
    }

    /// Cycle de test couvrant aujourd'hui, avec des séances du jour — pour vérifier que
    /// l'Accueil relie bien Programme → Cycle → Séances du jour. Temporaire, indépendant du
    /// seed des programmes (sinon il ne s'exécute jamais une fois les programmes déjà créés).
    static func seedTestCycleIfNeeded(context: ModelContext) {
        let cycleDescriptor = FetchDescriptor<Cycle>(predicate: #Predicate { $0.name == "Cycle test" })
        if let existing = try? context.fetch(cycleDescriptor), !existing.isEmpty {
            return
        }
        let programDescriptor = FetchDescriptor<TrainingProgram>(predicate: #Predicate { $0.title == "Perte de gras" })
        guard let perteDeGras = (try? context.fetch(programDescriptor))?.first else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func days(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today) ?? today }

        let cycle = Cycle(
            name: "Cycle test",
            startDate: days(-3),
            endDate: days(25),
            type: .standard,
            isActive: false,
            program: perteDeGras,
            objectifsPrincipaux: [.hypertrophie, .force]
        )
        context.insert(cycle)

        let todayWeekday = calendar.component(.weekday, from: today)

        let muscu = CycleSession(
            weekNumber: cycle.weekNumber(for: today),
            weekday: todayWeekday,
            title: "Push test",
            kind: .musculation,
            objective: .hypertrophie,
            order: 0
        )
        muscu.cycle = cycle
        context.insert(muscu)
        let ex1 = PlannedExercise(muscleGroup: "Pectoraux", exerciseName: "Développé couché", resistanceMode: .poidsLibre, targetSets: 3, targetWeight: 60, isRepsRange: true, targetRepsMin: 8, targetRepsMax: 10, order: 0)
        ex1.session = muscu
        context.insert(ex1)
        let ex2 = PlannedExercise(muscleGroup: "Épaules", exerciseName: "Développé militaire haltères", resistanceMode: .poidsLibre, targetSets: 3, targetWeight: 16, isRepsRange: true, targetRepsMin: 8, targetRepsMax: 10, order: 1)
        ex2.session = muscu
        context.insert(ex2)

        let cardio = CycleSession(
            weekNumber: cycle.weekNumber(for: today),
            weekday: todayWeekday,
            title: "Footing test",
            kind: .autre,
            objective: .enduranceAerobie,
            sessionDescription: "40 minutes en endurance fondamentale, zone 2.",
            order: 1
        )
        cardio.cycle = cycle
        context.insert(cardio)
    }

    /// Complète la bibliothèque d'exercices personnelle avec le répertoire réel de l'utilisateur
    /// (hors plan de séance actif) — additif et idempotent, s'exécute même si un cycle existe déjà.
    static func seedExerciseLibraryIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<ExerciseDefinition>()
        let existing = (try? context.fetch(descriptor)) ?? []

        // Renomme en place les entrées ajoutées lors d'un précédent lancement dont le nom
        // répétait le mode de résistance (déjà saisi séparément à chaque série) — évite les doublons.
        let renames: [String: String] = [
            "Extension lombaire (banc à lombaires)": "Extension lombaire",
            "Pull-over à la poulie haute": "Pull-over poulie haute",
            "Butterfly (machine)": "Butterfly",
            "Chest press (machine)": "Chest press",
            "Rear delt fly (machine)": "Rear delt fly",
            "Extension triceps kickback (haltère)": "Kick-back triceps",
            "Extension mollet debout (machine)": "Extension mollet debout",
            "Squat (barre)": "Squat",
            "Squat bulgare (haltères)": "Squat bulgare",
            "Curl supination barre EZ": "Curl barre EZ",
            "Élévations latérales buste penché (l'oiseau)": "L'oiseau",
            // Erreur d'interprétation initiale : cette entrée visait le mauvais mouvement (attache
            // corde du pushdown) — le second exercice triceps décrit est en fait une extension nuque
            // à la poulie basse, dos à la poulie, pas une variante d'attache du même mouvement.
            // Rebaptisée une seconde fois pour rester dans la même famille de nom que l'originale.
            "Triceps poulie haute (corde)": "Triceps poulie haute (horizontal)",
            "Extension triceps poulie basse (nuque)": "Triceps poulie haute (horizontal)",
            "Shrug (haussement d'épaules)": "Shrug",
            "Pompe classique": "Pompe",
            "Crunch à la poulie haute (prière)": "Crunch à la poulie haute",
            "Tirage horizontal (machine)": "Tirage horizontal",
            "Triceps poulie haute": "Triceps poulie haute (vertical)",
            "Abdos barre (genou)": "Relevé de genoux à la barre",
            "Soulevé de terre tendu unilatéral": "Soulevé de terre jambes tendues"
        ]
        for definition in existing {
            if let newName = renames[definition.name] {
                definition.name = newName
            }
        }

        // Tirage menton reclassé en Dos (confirmé : trapèzes = dos pour l'utilisateur, on ne
        // décompose pas plus finement les groupes musculaires).
        if let tirageMenton = existing.first(where: { $0.name == "Tirage menton" }) {
            tirageMenton.muscleGroup = "Dos"
        }

        // Supprimées de la bibliothèque : ajoutées par erreur, jamais faites, ou redondantes avec
        // un exercice générique déjà existant (Tractions pronation ≈ Tractions ; Curl machine ≈
        // Curl + mode "machine" précisé à la saisie).
        let deletedNames: Set<String> = [
            "Pompe genou", "Tractions pronation", "Curl machine", "Glute machine",
            // Exercices de test créés depuis l'app pour essayer "Créer un nouvel exercice".
            "Test à supprimer", "Élévation test"
        ]
        for definition in existing where deletedNames.contains(definition.name) {
            context.delete(definition)
        }

        var seen = Set(
            existing
                .filter { !deletedNames.contains($0.name) }
                .map { "\($0.muscleGroup)|\($0.name)" }
        )

        // Noms officiels, groupés par groupe musculaire réel. Tirage menton classé en Épaules
        // (cible surtout deltoïdes latéraux/trapèzes) plutôt qu'en Dos.
        // Convention : le mode de résistance (poids libre/machine/poids du corps/élastique) n'est
        // jamais répété dans le nom — déjà saisi à part à chaque série. Un mot d'équipement n'est
        // gardé que quand il définit un mouvement réellement différent (ex: développé haltères vs
        // barre), jamais entre parenthèses juste pour signaler "c'est une machine".
        let library: [(name: String, muscle: String)] = [
            // Dos
            ("Extension lombaire", "Dos"),
            ("Soulevé de terre", "Dos"),
            ("Pull-over poulie haute", "Dos"),
            ("Tirage menton", "Dos"),
            ("Tractions supination", "Dos"),
            ("Tractions neutre", "Dos"),
            ("Shrug", "Dos"),
            ("Tirage vertical", "Dos"),
            // Pectoraux
            ("Développé couché haltères", "Pectoraux"),
            ("Développé incliné haltères", "Pectoraux"),
            ("Développé semi-incliné haltères", "Pectoraux"),
            ("Butterfly", "Pectoraux"),
            ("Chest press", "Pectoraux"),
            ("Pompe", "Pectoraux"),
            ("Pompe incliné", "Pectoraux"),
            ("Pompe décliné", "Pectoraux"),
            ("Écarté poulie haute", "Pectoraux"),
            ("Écarté poulie basse", "Pectoraux"),
            // Épaules
            ("L'oiseau", "Épaules"),
            ("Rear delt fly", "Épaules"),
            ("Développé militaire", "Épaules"),
            ("Élévations frontales", "Épaules"),
            ("Rotation externe (coiffe des rotateurs)", "Épaules"),
            // Biceps
            ("Curl barre EZ", "Biceps"),
            ("Curl inversé barre EZ", "Biceps"),
            ("Curl prise marteau", "Biceps"),
            ("Curl incliné haltères", "Biceps"),
            ("Curl haltères", "Biceps"),
            // Triceps
            ("Dips machine", "Triceps"),
            ("Kick-back triceps", "Triceps"),
            ("Triceps poulie haute (horizontal)", "Triceps"),
            // Jambes
            ("Soulevé de terre jambes tendues", "Jambes"),
            ("Extension mollet debout", "Jambes"),
            ("Machine adducteurs", "Jambes"),
            ("Machine abducteurs", "Jambes"),
            ("Squat", "Jambes"),
            ("Squat bulgare", "Jambes"),
            ("Hip thrust", "Jambes"),
            ("Fentes", "Jambes"),
            // Abdos
            ("Relevé de genoux à la chaise romaine", "Abdos"),
            ("Abs wheel", "Abdos"),
            ("Crunch à la poulie haute", "Abdos")
        ]

        for entry in library where seen.insert("\(entry.muscle)|\(entry.name)").inserted {
            context.insert(ExerciseDefinition(name: entry.name, muscleGroup: entry.muscle))
        }
    }
}
