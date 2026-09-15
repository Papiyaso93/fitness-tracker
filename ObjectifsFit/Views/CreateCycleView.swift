import SwiftUI
import SwiftData

/// Formulaire de création d'un cycle dans le nouveau constructeur de programme.
struct CreateCycleView: View {
    let program: TrainingProgram

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var startDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var weekCount: Int = 4
    @State private var principales: Set<PhysicalQuality> = []
    @State private var secondaires: Set<PhysicalQuality> = []
    @State private var objectiveDrafts: [ObjectiveDraft] = []
    @State private var showingAddObjective = false

    private var endDate: Date {
        Calendar.current.date(byAdding: .day, value: weekCount * 7, to: startDate) ?? startDate
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !principales.isEmpty
    }

    /// Métriques déjà suivies par le programme — le cycle ne peut viser autre chose sans passer par "Autre".
    private var programMetrics: [ObjectiveMetricType] {
        let all = program.principalObjectives + program.secondaryObjectives
        var seen = Set<ObjectiveMetricType>()
        var result: [ObjectiveMetricType] = []
        for objective in all {
            if let type = objective.metricType, type != .autre, seen.insert(type).inserted {
                result.append(type)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nom *").font(.system(size: 13)).foregroundStyle(AppTheme.textSecondary)
                        TextField("Cycle 2 — Reprise", text: $name)
                    }
                    DatePicker("Date de début", selection: $startDate, displayedComponents: .date)
                    Stepper("Durée : \(weekCount) semaine\(weekCount > 1 ? "s" : "")", value: $weekCount, in: 1...12)
                    LabeledContent("Fin prévue") {
                        Text(formatted(endDate)).foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Section {
                    NavigationLink {
                        QualitySelectionView(title: "Qualités principales", selection: $principales)
                    } label: {
                        HStack {
                            Text("Qualités principales")
                            Spacer()
                            Text(summaryLabel(principales))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                } header: {
                    Text("Qualités principales *")
                } footer: {
                    Text("Qualité(s) que ce cycle cherche à développer en priorité.")
                }

                Section {
                    NavigationLink {
                        QualitySelectionView(title: "Qualités secondaires", selection: $secondaires)
                    } label: {
                        HStack {
                            Text("Qualités secondaires")
                            Spacer()
                            Text(summaryLabel(secondaires))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                } header: {
                    Text("Qualités secondaires")
                } footer: {
                    Text("Qualités travaillées en complément, sans être la priorité du cycle.")
                }

                Section {
                    ForEach(objectiveDrafts) { draft in
                        HStack {
                            Text(draft.summary)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Button {
                                objectiveDrafts.removeAll { $0.id == draft.id }
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        showingAddObjective = true
                    } label: {
                        Label("Ajouter un objectif", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Objectifs du cycle")
                } footer: {
                    Text("Jalon intermédiaire vers l'objectif du programme.")
                }
            }
            .navigationTitle("Nouveau cycle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { save() }
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingAddObjective) {
                AddObjectiveDraftView(allowedMetrics: programMetrics.isEmpty ? nil : programMetrics) { draft in
                    objectiveDrafts.append(draft)
                }
            }
        }
    }

    private func summaryLabel(_ selection: Set<PhysicalQuality>) -> String {
        selection.isEmpty ? "Aucune" : selection.map(\.rawValue).joined(separator: ", ")
    }

    private func save() {
        let cycle = Cycle(
            name: name.trimmingCharacters(in: .whitespaces),
            startDate: startDate,
            endDate: endDate,
            type: .standard,
            isActive: false,
            program: program,
            objectifsPrincipaux: Array(principales),
            objectifsSecondaires: Array(secondaires)
        )
        context.insert(cycle)

        for (index, draft) in objectiveDrafts.enumerated() {
            let objective = ProgramObjective(
                category: .principal,
                isMeasurable: draft.isMeasurable,
                freeText: draft.isMeasurable ? nil : draft.freeText,
                metricType: draft.isMeasurable ? draft.metricType : nil,
                customMetricName: draft.customMetricName,
                customUnit: draft.customUnit,
                mode: draft.isMeasurable ? draft.mode : nil,
                startValue: draft.isMeasurable && draft.mode == .progression ? Double(draft.startValue) : nil,
                targetValue: draft.isMeasurable ? Double(draft.targetValue) : nil,
                order: index
            )
            objective.cycle = cycle
            context.insert(objective)
        }

        dismiss()
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
}
