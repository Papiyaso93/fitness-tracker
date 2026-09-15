import Foundation

/// Coefficients par défaut pour les exercices au poids du corps : fraction du poids de corps
/// réellement soulevée, utilisée dans le calcul du tonnage. Basé sur des repères biomécaniques
/// usuels (ex: pompes classiques ~64-70% du poids de corps, tractions/dips ~90%).
enum BodyweightCoefficients {
    private static let table: [(match: String, coefficient: Double)] = [
        ("pompe décliné", 0.74),
        ("pompe incliné", 0.41),
        ("pompe genou", 0.50),
        ("pompe", 0.65),
        ("traction", 0.90),
        ("dip", 0.90),
        ("extension lombaire", 0.50),
        ("gainage", 0.30),
        ("relevé de genoux", 0.30),
        ("abdo", 0.30),
        ("abs wheel", 0.40)
    ]

    /// Cherche une correspondance approximative par nom d'exercice (insensible à la casse),
    /// sinon retombe sur 1.0 (poids de corps complet).
    static func defaultCoefficient(forExerciseNamed name: String) -> Double {
        let normalized = name.lowercased()
        for entry in table where normalized.contains(entry.match) {
            return entry.coefficient
        }
        return 1.0
    }
}
