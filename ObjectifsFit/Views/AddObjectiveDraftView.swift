import SwiftUI

/// Brouillon d'objectif en cours de saisie, avant que le programme ne soit créé (évite d'insérer
/// des objets orphelins dans SwiftData si l'utilisateur annule le formulaire).
struct ObjectiveDraft: Identifiable {
    let id = UUID()
    var isMeasurable: Bool
    var freeText: String = ""
    var metricType: ObjectiveMetricType = .masseGrasse
    var customMetricName: String = ""
    var customUnit: String = ""
    var mode: ObjectiveMode = .progression
    var startValue: String = ""
    var targetValue: String = ""

    private var metricName: String {
        metricType == .autre ? customMetricName : metricType.rawValue
    }

    private var metricUnit: String {
        metricType == .autre ? customUnit : metricType.unit
    }

    var summary: String {
        if !isMeasurable {
            return freeText
        }
        switch mode {
        case .progression:
            let start = startValue.isEmpty ? "?" : "\(startValue)\(metricUnit)"
            let target = targetValue.isEmpty ? "?" : "\(targetValue)\(metricUnit)"
            return "\(metricName) : \(start) → \(target)"
        case .maintien:
            let target = targetValue.isEmpty ? "?" : "\(targetValue)\(metricUnit)"
            return "\(metricName) : maintenir \(target)"
        }
    }

    /// Nom de l'objectif seul, pour un affichage en 2 lignes (nom en avant, cible en dessous)
    /// plutôt que la phrase compacte de `summary`.
    var name: String {
        isMeasurable ? metricName : freeText
    }

    var progressionText: String? {
        guard isMeasurable else { return nil }
        switch mode {
        case .progression:
            let start = startValue.isEmpty ? "?" : "\(startValue)\(metricUnit)"
            let target = targetValue.isEmpty ? "?" : "\(targetValue)\(metricUnit)"
            return "Passer de \(start) à \(target)"
        case .maintien:
            let target = targetValue.isEmpty ? "?" : "\(targetValue)\(metricUnit)"
            return "Maintenir \(target)"
        }
    }
}

/// Formulaire d'ajout d'un objectif ou indicateur — texte libre, ou cible chiffrée
/// (progression X→Y, ou maintien) sur une métrique suivie par l'app.
struct AddObjectiveDraftView: View {
    /// Si fourni, limite le choix de métrique à cette liste (+ "Autre" toujours ajouté) — utilisé
    /// pour les objectifs de cycle, restreints aux métriques déjà suivies par le programme.
    var allowedMetrics: [ObjectiveMetricType]?
    let onSave: (ObjectiveDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isMeasurable = true
    @State private var freeText = ""
    @State private var metricType: ObjectiveMetricType = .masseGrasse
    @State private var customMetricName = ""
    @State private var customUnit = ""
    @State private var mode: ObjectiveMode = .progression
    @State private var startValue = ""
    @State private var targetValue = ""

    init(allowedMetrics: [ObjectiveMetricType]? = nil, onSave: @escaping (ObjectiveDraft) -> Void) {
        self.allowedMetrics = allowedMetrics
        self.onSave = onSave
        _metricType = State(initialValue: allowedMetrics?.first ?? .masseGrasse)
    }

    private var availableMetrics: [ObjectiveMetricType] {
        guard let allowedMetrics, !allowedMetrics.isEmpty else { return ObjectiveMetricType.allCases }
        return allowedMetrics + [.autre]
    }

    private var canSave: Bool {
        if !isMeasurable {
            return !freeText.trimmingCharacters(in: .whitespaces).isEmpty
        }
        if metricType == .autre && customMetricName.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        if mode == .progression {
            return Double(startValue) != nil && Double(targetValue) != nil
        }
        return Double(targetValue) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AppSegmentedControl(options: [(true, "Chiffré"), (false, "Texte libre")], selection: $isMeasurable)
                        .listRowInsets(EdgeInsets())
                        .padding(4)
                } header: { formSectionHeader("Type", required: true) }

                if isMeasurable {
                    Section {
                        AppMenuField(
                            label: "Métrique",
                            options: availableMetrics.map { ($0, $0.rawValue) },
                            selection: $metricType,
                            required: true,
                            showsLabel: false
                        )
                        if metricType == .autre {
                            VStack(alignment: .leading, spacing: 4) {
                                fieldCaption("Nom", required: true)
                                TextField("Ex: fréquence cardiaque au repos", text: $customMetricName)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                fieldCaption("Unité")
                                TextField("Ex: bpm, reps, min…", text: $customUnit)
                            }
                        }
                    } header: {
                        formSectionHeader("Métrique", required: metricType != .autre)
                    } footer: {
                        if allowedMetrics != nil && !(allowedMetrics?.isEmpty ?? true) {
                            Text("Limitée aux métriques déjà suivies par le programme.")
                        }
                    }

                    Section {
                        AppSegmentedControl(options: ObjectiveMode.allCases.map { ($0, $0.rawValue) }, selection: $mode)
                            .listRowInsets(EdgeInsets())
                            .padding(4)

                        if mode == .progression {
                            LabeledContent {
                                TextField("0", text: $startValue)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                            } label: {
                                fieldLabel("Valeur de départ\(unitSuffix)", required: true)
                            }
                        }
                        LabeledContent {
                            TextField("0", text: $targetValue)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        } label: {
                            fieldLabel(mode == .progression ? "Valeur cible\(unitSuffix)" : "Valeur à maintenir\(unitSuffix)", required: true)
                        }
                    } header: { formSectionHeader("Cible") }
                } else {
                    Section {
                        TextField("Ex: redevenir plus explosif", text: $freeText, axis: .vertical)
                    } header: { formSectionHeader("Description", required: true) }
                }
            }
            .navigationTitle("Nouvel objectif")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        var draft = ObjectiveDraft(isMeasurable: isMeasurable)
                        draft.freeText = freeText
                        draft.metricType = metricType
                        draft.customMetricName = customMetricName
                        draft.customUnit = customUnit
                        draft.mode = mode
                        draft.startValue = startValue
                        draft.targetValue = targetValue
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var unitSuffix: String {
        let unit = metricType == .autre ? customUnit : metricType.unit
        return unit.isEmpty ? "" : " (\(unit))"
    }
}
