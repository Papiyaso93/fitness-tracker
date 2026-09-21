import Foundation
import SwiftData

/// Importe l'historique de séries loguées ailleurs (ex: export Notion) directement en `PlannedSetEntry`,
/// sans reconstruire de séance/cycle fictif — ces séries existent hors de tout `SessionCompletion` et
/// alimentent quand même le Tableau de bord (qui interroge `PlannedSetEntry` directement).
enum HistoryCSVImporter {

    struct ImportResult {
        var importedCount = 0
        var duplicateCount = 0
        var skippedCount = 0
        var unmatchedExerciseNames: Set<String> = []
    }

    enum ImportError: Error {
        case cannotReadFile
        case missingHeader
    }

    /// CSV → nom canonique de la bibliothèque. Un nom absent d'ici est cherché tel quel dans la
    /// bibliothèque ; s'il n'y correspond toujours pas, la ligne est ignorée et remontée dans
    /// `unmatchedExerciseNames` plutôt qu'importée sous un nom qui n'existe pas.
    private static let exerciseNameMapping: [String: String] = [
        "Abdos barre (genou)": "Relevé de genoux à la barre",
        "Abdos chaise romaine (genou)": "Relevé de genoux à la chaise romaine",
        "Curl banc incliné": "Curl incliné haltères",
        "Curl machine": "Curl",
        "Curl pronation barre EZ": "Curl inversé barre EZ",
        "Dips machine": "Dips",
        "Développé militaire haltères": "Développé militaire",
        "Développé semi incliné haltères": "Développé semi-incliné haltères",
        "Elévations latérales": "Élévations latérales",
        "Extension lombaires": "Extension lombaire",
        "Glute machine": "Hip thrust",
        "Kick back": "Kick-back triceps",
        "Machine abducteur": "Abducteurs",
        "Machine adducteur": "Adducteurs",
        "Machine butterfly": "Butterfly",
        "Pompes": "Pompe",
        "Pull-over poulie": "Pull-over poulie haute",
        "Rear delt machine": "Rear delt fly",
        "Soulevé de terre tendu unilatéral": "Soulevé de terre jambes tendues",
        "Tirage bucheron": "Tirage bûcheron",
        "Tirage horizontal (machine)": "Tirage horizontal",
        "Triceps poulie haute": "Triceps poulie haute (vertical)",
        "Triceps poulie haute bis": "Triceps poulie haute (horizontal)"
    ]

    /// Séries sans équivalent poids/reps pertinent (ex: gainage isométrique) — exclues plutôt
    /// qu'importées avec des valeurs à 0 qui fausseraient les KPI.
    private static let ignoredExerciseNames: Set<String> = ["Gainage classique"]

    private static let resistanceModeMapping: [String: ResistanceMode] = [
        "poids libre": .poidsLibre,
        "machine": .machine,
        "poids du corps": .poidsDuCorps,
        "lesté": .leste,
        "elastique": .elastique,
        "élastique": .elastique
    ]

    private static let sensationByLabel: [String: SensationLevel] = Dictionary(
        uniqueKeysWithValues: SensationLevel.allCases.map { ($0.label, $0) }
    )

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssxxx"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func importCSV(url: URL, context: ModelContext) throws -> ImportResult {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url), let content = String(data: data, encoding: .utf8) else {
            throw ImportError.cannotReadFile
        }

        let rows = parseCSV(content)
        guard let header = rows.first else { throw ImportError.missingHeader }

        func columnIndex(_ name: String) -> Int? { header.firstIndex(of: name) }

        guard let dateIndex = columnIndex("Date"),
              let muscleIndex = columnIndex("Groupe musculaire"),
              let exerciseIndex = columnIndex("Exercice"),
              let modeIndex = columnIndex("Mode de résistance"),
              let weightIndex = columnIndex("Poids (kg)"),
              let repsIndex = columnIndex("Répétitions"),
              let sensationIndex = columnIndex("Sensation"),
              let commentIndex = columnIndex("Commentaire"),
              let bodyWeightIndex = columnIndex("Poids de corps"),
              let coefficientIndex = columnIndex("Coefficient") else {
            throw ImportError.missingHeader
        }

        let exerciseLibrary = (try? context.fetch(FetchDescriptor<ExerciseDefinition>())) ?? []
        let muscleGroupByName = Dictionary(exerciseLibrary.map { ($0.name, $0.muscleGroup) }, uniquingKeysWith: { first, _ in first })

        let existingEntries = (try? context.fetch(FetchDescriptor<PlannedSetEntry>())) ?? []
        var existingSignatures = Set(existingEntries.map { signature(date: $0.date, exerciseName: $0.exerciseName, reps: $0.reps, weight: $0.weight) })

        var result = ImportResult()

        for row in rows.dropFirst() where row.count > max(dateIndex, exerciseIndex, sensationIndex) {
            let rawExerciseName = row[exerciseIndex].trimmingCharacters(in: .whitespaces)
            guard !rawExerciseName.isEmpty else { continue }

            if ignoredExerciseNames.contains(rawExerciseName) {
                result.skippedCount += 1
                continue
            }

            let canonicalName = exerciseNameMapping[rawExerciseName] ?? rawExerciseName
            guard let muscleGroup = muscleGroupByName[canonicalName] else {
                result.unmatchedExerciseNames.insert(rawExerciseName)
                result.skippedCount += 1
                continue
            }

            guard let date = dateFormatter.date(from: row[dateIndex]) else {
                result.skippedCount += 1
                continue
            }

            let modeKey = row[modeIndex].trimmingCharacters(in: .whitespaces).lowercased()
            let resistanceMode = resistanceModeMapping[modeKey] ?? .poidsDuCorps

            // Les répétitions sont exportées en décimal ("10.0") — Int("10.0") échoue et retombe
            // silencieusement à 0, d'où le passage par Double d'abord.
            let reps = Int(Double(row[repsIndex]) ?? 0)
            let weight = Double(row[weightIndex])
            let bodyWeight = Double(row[bodyWeightIndex])
            let coefficient = Double(row[coefficientIndex]) ?? 1.0
            let comment = row[commentIndex].trimmingCharacters(in: .whitespaces)
            let sensationLabel = row[sensationIndex].trimmingCharacters(in: .whitespaces)
            let sensation = sensationByLabel[sensationLabel] ?? .normal

            let sig = signature(date: date, exerciseName: canonicalName, reps: reps, weight: weight)
            guard !existingSignatures.contains(sig) else {
                result.duplicateCount += 1
                continue
            }
            existingSignatures.insert(sig)

            _ = row[muscleIndex] // groupe CSV ignoré au profit de celui de la bibliothèque, déjà harmonisé

            let entry = PlannedSetEntry(
                date: date,
                exerciseName: canonicalName,
                muscleGroup: muscleGroup,
                resistanceMode: resistanceMode,
                weight: weight,
                bodyWeight: bodyWeight,
                reps: reps,
                sensation: sensation,
                comment: comment.isEmpty ? nil : comment,
                coefficient: coefficient
            )
            context.insert(entry)
            result.importedCount += 1
        }

        return result
    }

    private static func signature(date: Date, exerciseName: String, reps: Int, weight: Double?) -> String {
        "\(date.timeIntervalSince1970)|\(exerciseName)|\(reps)|\(weight ?? -1)"
    }

    /// Parseur CSV minimal mais correct sur les guillemets (le seul cas d'échappement présent dans
    /// cet export : des commentaires libres contenant des virgules).
    private static func parseCSV(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false
        var iterator = content.makeIterator()

        while let char = iterator.next() {
            if insideQuotes {
                if char == "\"" {
                    insideQuotes = false
                } else {
                    currentField.append(char)
                }
            } else {
                switch char {
                case "\"":
                    insideQuotes = true
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                case "\n":
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                case "\r":
                    continue
                default:
                    currentField.append(char)
                }
            }
        }
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }
        return rows
    }
}
