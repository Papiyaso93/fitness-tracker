import Foundation
import SwiftData

enum SeedData {

    /// Reprend l'ancien rappel transit codé en dur (21h) comme premier `Reminder` par défaut, une
    /// seule fois — l'utilisateur peut ensuite le modifier ou le supprimer librement comme les autres.
    static func seedDefaultReminderIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Reminder>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        let reminder = Reminder(
            title: "Transit du jour",
            message: "Tu n'as pas encore renseigné ton transit aujourd'hui.",
            hour: 21,
            minute: 0
        )
        context.insert(reminder)
        NotificationManager.schedule(reminder)
    }

    /// Bibliothèque d'exercices livrée avec l'app — additif et idempotent, complète la liste sans
    /// jamais écraser les exercices que l'utilisateur a ajoutés/modifiés lui-même.
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
            "Soulevé de terre tendu unilatéral": "Soulevé de terre jambes tendues",
            // "Machine" répétait le mode de résistance dans le nom (contraire à la règle posée
            // juste au-dessus) — déjà saisi séparément à chaque série, et ces exercices peuvent
            // aussi se faire à l'élastique.
            "Dips machine": "Dips",
            "Machine adducteurs": "Adducteurs",
            "Machine abducteurs": "Abducteurs"
        ]
        for definition in existing {
            if let newName = renames[definition.name] {
                definition.name = newName
            }
        }

        // Tirage menton reclassé en Épaules — son muscle principal (deltoïdes latéraux) est un
        // muscle d'épaule, les trapèzes ne sont que secondaires (cf. table muscles ciblés).
        if let tirageMenton = existing.first(where: { $0.name == "Tirage menton" }) {
            tirageMenton.muscleGroup = "Épaules"
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
        // Muscles ciblés vérifiés (ExRx.net et équivalents en science du sport, cf. conversation
        // de recherche du 2026-09-20) — jamais devinés. `primary`/`secondary` sont au niveau muscle
        // précis, distinct de `muscle` qui reste le groupe large existant.
        let library: [(name: String, muscle: String, primary: [String], secondary: [String])] = [
            // Dos
            ("Extension lombaire", "Dos", ["Lombaires"], ["Fessiers", "Ischio-jambiers"]),
            ("Soulevé de terre", "Dos", ["Lombaires", "Fessiers"], ["Ischio-jambiers", "Quadriceps", "Grand dorsal", "Trapèzes"]),
            ("Pull-over poulie haute", "Dos", ["Grand dorsal"], ["Grand rond", "Grand pectoral sternal", "Triceps brachial"]),
            ("Tractions", "Dos", ["Grand dorsal"], ["Grand rond", "Rhomboïdes", "Trapèzes inférieurs", "Biceps brachial"]),
            ("Tractions supination", "Dos", ["Grand dorsal", "Biceps brachial"], ["Grand rond", "Rhomboïdes", "Trapèzes inférieurs"]),
            ("Tractions neutre", "Dos", ["Grand dorsal", "Brachial"], ["Biceps brachial", "Grand rond", "Trapèzes"]),
            ("Shrug", "Dos", ["Trapèzes supérieurs"], ["Trapèzes moyens", "Releveur de la scapula"]),
            ("Tirage vertical", "Dos", ["Grand dorsal"], ["Biceps brachial", "Grand rond", "Rhomboïdes", "Trapèzes inférieurs"]),
            ("Tirage horizontal", "Dos", ["Grand dorsal", "Rhomboïdes", "Trapèzes moyens"], ["Biceps brachial", "Deltoïde postérieur", "Lombaires"]),
            ("Tirage bûcheron", "Dos", ["Grand dorsal"], ["Trapèzes", "Rhomboïdes", "Biceps brachial", "Lombaires"]),
            // Pectoraux
            ("Développé couché haltères", "Pectoraux", ["Grand pectoral sternal"], ["Deltoïde antérieur", "Triceps brachial"]),
            ("Développé incliné haltères", "Pectoraux", ["Grand pectoral claviculaire"], ["Deltoïde antérieur", "Triceps brachial"]),
            ("Développé semi-incliné haltères", "Pectoraux", ["Grand pectoral claviculaire", "Grand pectoral sternal"], ["Deltoïde antérieur", "Triceps brachial"]),
            ("Butterfly", "Pectoraux", ["Grand pectoral sternal"], ["Deltoïde antérieur"]),
            ("Chest press", "Pectoraux", ["Grand pectoral sternal"], ["Deltoïde antérieur", "Triceps brachial"]),
            ("Pompe", "Pectoraux", ["Grand pectoral sternal"], ["Deltoïde antérieur", "Triceps brachial"]),
            ("Pompe incliné", "Pectoraux", ["Grand pectoral sternal"], ["Deltoïde antérieur", "Triceps brachial"]),
            ("Pompe décliné", "Pectoraux", ["Grand pectoral claviculaire"], ["Deltoïde antérieur", "Triceps brachial"]),
            ("Écarté poulie haute", "Pectoraux", ["Grand pectoral sternal"], ["Deltoïde antérieur"]),
            ("Écarté poulie basse", "Pectoraux", ["Grand pectoral claviculaire"], ["Deltoïde antérieur"]),
            // Épaules
            ("Tirage menton", "Épaules", ["Deltoïde latéral"], ["Trapèzes", "Biceps brachial"]),
            ("Élévations latérales", "Épaules", ["Deltoïde latéral"], ["Trapèzes supérieurs", "Supra-épineux", "Deltoïde antérieur"]),
            ("L'oiseau", "Épaules", ["Deltoïde postérieur"], ["Trapèzes", "Rhomboïdes", "Infra-épineux", "Petit rond"]),
            ("Rear delt fly", "Épaules", ["Deltoïde postérieur"], ["Trapèzes", "Rhomboïdes", "Infra-épineux", "Petit rond"]),
            ("Développé militaire", "Épaules", ["Deltoïde antérieur"], ["Deltoïde latéral", "Triceps brachial", "Trapèzes"]),
            ("Élévations frontales", "Épaules", ["Deltoïde antérieur"], ["Grand pectoral claviculaire", "Deltoïde latéral"]),
            ("Rotation externe (coiffe des rotateurs)", "Épaules", ["Infra-épineux", "Petit rond"], ["Deltoïde postérieur"]),
            // Biceps
            ("Curl barre EZ", "Biceps", ["Biceps brachial"], ["Brachial", "Brachio-radial"]),
            ("Curl inversé barre EZ", "Biceps", ["Brachial", "Brachio-radial"], ["Biceps brachial"]),
            ("Curl prise marteau", "Biceps", ["Brachio-radial"], ["Brachial", "Biceps brachial"]),
            ("Curl incliné haltères", "Biceps", ["Biceps brachial"], ["Brachial"]),
            ("Curl haltères", "Biceps", ["Biceps brachial"], ["Brachial", "Brachio-radial"]),
            // Triceps
            ("Dips", "Triceps", ["Triceps brachial vaste externe", "Triceps brachial vaste interne"], ["Grand pectoral sternal", "Deltoïde antérieur"]),
            ("Kick-back triceps", "Triceps", ["Triceps brachial vaste externe"], []),
            ("Triceps poulie haute (vertical)", "Triceps", ["Triceps brachial vaste externe", "Triceps brachial vaste interne"], []),
            ("Triceps poulie haute (horizontal)", "Triceps", ["Triceps brachial vaste externe", "Triceps brachial vaste interne"], []),
            ("Extension triceps nuque", "Triceps", ["Triceps brachial longue portion"], []),
            // Jambes
            ("Soulevé de terre jambes tendues", "Jambes", ["Ischio-jambiers", "Fessiers"], ["Lombaires", "Adducteurs"]),
            ("Extension mollet debout", "Jambes", ["Mollet — Gastrocnémien"], ["Mollet — Soléaire"]),
            ("Extension mollet assis", "Jambes", ["Mollet — Soléaire"], ["Mollet — Gastrocnémien"]),
            ("Adducteurs", "Jambes", ["Long adducteur", "Grand adducteur"], ["Gracile", "Pectiné"]),
            ("Abducteurs", "Jambes", ["Moyen fessier", "Petit fessier"], ["Tenseur du fascia lata", "Grand fessier"]),
            ("Squat", "Jambes", ["Quadriceps", "Grand fessier"], ["Ischio-jambiers", "Adducteurs", "Mollets"]),
            ("Squat bulgare", "Jambes", ["Quadriceps"], ["Grand fessier", "Ischio-jambiers", "Adducteurs"]),
            ("Hip thrust", "Jambes", ["Grand fessier"], ["Ischio-jambiers", "Quadriceps"]),
            ("Fentes", "Jambes", ["Quadriceps"], ["Grand fessier", "Ischio-jambiers", "Adducteurs"]),
            ("Leg extension", "Jambes", ["Quadriceps"], []),
            ("Leg curl", "Jambes", ["Ischio-jambiers"], ["Mollet — Gastrocnémien"]),
            ("Presse inclinée", "Jambes", ["Quadriceps"], ["Grand fessier", "Ischio-jambiers"]),
            ("Presse horizontale", "Jambes", ["Quadriceps"], ["Grand fessier", "Ischio-jambiers"]),
            // Abdos
            ("Relevé de genoux à la chaise romaine", "Abdos", ["Grand droit de l'abdomen"], ["Obliques", "Fléchisseurs de hanche"]),
            ("Relevé de genoux à la barre", "Abdos", ["Grand droit de l'abdomen"], ["Obliques", "Fléchisseurs de hanche"]),
            ("Abs wheel", "Abdos", ["Fléchisseurs de hanche"], ["Grand droit de l'abdomen", "Obliques", "Grand dorsal", "Transverse de l'abdomen"]),
            ("Crunch à la poulie haute", "Abdos", ["Grand droit de l'abdomen"], ["Obliques"]),
            ("Woodchop à la poulie", "Abdos", ["Obliques"], ["Grand droit de l'abdomen", "Transverse de l'abdomen"])
        ]

        // Resynchronise les muscles ciblés sur les exercices déjà en base (pas juste les nouveaux)
        // — cette donnée n'est pas éditable par l'utilisateur, donc sûr à réécrire à chaque lancement
        // si la table de correspondance évolue.
        let musclesByName = Dictionary(uniqueKeysWithValues: library.map { ($0.name, ($0.primary, $0.secondary)) })
        for definition in existing {
            if let (primary, secondary) = musclesByName[definition.name] {
                definition.primaryMuscles = primary
                definition.secondaryMuscles = secondary
            }
        }

        for entry in library where seen.insert("\(entry.muscle)|\(entry.name)").inserted {
            context.insert(ExerciseDefinition(
                name: entry.name,
                muscleGroup: entry.muscle,
                primaryMuscles: entry.primary,
                secondaryMuscles: entry.secondary
            ))
        }
    }
}
