import Foundation

/// Prompt accompagnant l'export JSON lors du partage — conception validée le 2026-09-20 (voir
/// mémoire projet) : posture "coach sportif" plutôt que mimétisme des anciens bilans PDF, pas de
/// mention forcée des cycles (déjà dans les données), suivi des recommandations limité au bilan
/// le plus récent joint.
enum BilanPrompt {
    static let text = """
    Voici l'export complet de mes données (entraînement, nutrition, transit, sommeil, et l'historique de mes programmes/cycles) au format JSON. Mets-toi dans la peau d'un coach sportif qui analyse mes données pour la première fois : donne-moi un vrai avis structuré et pertinent — ce qui fonctionne, ce qui bloque, ce que tu recommandes concrètement, sans te forcer à suivre un template particulier. Si des objectifs de programme/cycle apparaissent dans les données, prends-les en compte. Si je joins d'anciens bilans, ils servent surtout de contexte historique — seul le plus récent mérite une vraie vérification de si ses recommandations ont été suivies.
    """

    /// Variante "fin de cycle" — nomme le cycle concerné, demande un verdict dessus spécifiquement,
    /// et gère les deux cas (cycle suivant déjà planifié à ajuster, ou à construire de zéro) sans
    /// que l'app ait besoin de le détecter elle-même : l'export contient déjà tous les cycles.
    static func cycleEnd(cycleName: String, startDate: Date, endDate: Date, objectivesSummary: String) -> String {
        """
        Voici l'export complet de mes données (entraînement, nutrition, transit, sommeil, et l'historique de mes programmes/cycles) au format JSON. Ce cycle se termine : « \(cycleName) » (du \(dateLabel(startDate)) au \(dateLabel(endDate))), avec pour objectif(s) : \(objectivesSummary). Mets-toi dans la peau d'un coach sportif : fais le bilan de ce cycle spécifiquement — l'objectif a-t-il été atteint, qu'est-ce qui a fonctionné, qu'est-ce qui a bloqué. Si un cycle suivant est déjà planifié dans les données, réexamine-le et propose des ajustements pertinents ; sinon, aide-moi à en construire un (durée, volume, focus) à partir de ce qui vient de se passer. Si je joins d'anciens bilans, ils servent surtout de contexte historique — seul le plus récent mérite une vraie vérification de si ses recommandations ont été suivies.
        """
    }

    /// Variante "fin de programme" — même logique que `cycleEnd`, adaptée aux dates optionnelles
    /// d'un programme.
    static func programEnd(programTitle: String, startDate: Date?, endDate: Date?, objectivesSummary: String) -> String {
        let dateRange: String
        switch (startDate, endDate) {
        case let (start?, end?): dateRange = " (du \(dateLabel(start)) au \(dateLabel(end)))"
        case let (nil, end?): dateRange = " (jusqu'au \(dateLabel(end)))"
        case let (start?, nil): dateRange = " (depuis le \(dateLabel(start)))"
        default: dateRange = ""
        }
        return """
        Voici l'export complet de mes données (entraînement, nutrition, transit, sommeil, et l'historique de mes programmes/cycles) au format JSON. Ce programme se termine : « \(programTitle) »\(dateRange), avec pour objectif(s) : \(objectivesSummary). Mets-toi dans la peau d'un coach sportif : fais le bilan de ce programme spécifiquement — l'objectif a-t-il été atteint, qu'est-ce qui a fonctionné, qu'est-ce qui a bloqué. Si un programme suivant est déjà planifié dans les données, réexamine-le et propose des ajustements pertinents ; sinon, aide-moi à en construire un (durée, volume, focus) à partir de ce qui vient de se passer. Si je joins d'anciens bilans, ils servent surtout de contexte historique — seul le plus récent mérite une vraie vérification de si ses recommandations ont été suivies.
        """
    }

    private static func dateLabel(_ date: Date) -> String {
        AppDateFormat.dayMonthYear.string(from: date)
    }
}
