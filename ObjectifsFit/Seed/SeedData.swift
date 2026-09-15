import Foundation
import SwiftData

enum SeedData {

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
