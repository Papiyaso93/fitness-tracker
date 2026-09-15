import SwiftUI
import SwiftData

/// Édition d'un cycle déjà créé : infos, qualités, objectifs (ajout/suppression directs), et
/// suppression du cycle.
struct EditCycleView: View {
    @Bindable var cycle: Cycle
    var onDelete: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var weekCount: Int
    @State private var principales: Set<PhysicalQuality>
    @State private var secondaires: Set<PhysicalQuality>
    @State private var showingAddObjective = false
    @State private var showingDeleteConfirmation = false

    init(cycle: Cycle, onDelete: @escaping () -> Void) {
        self.cycle = cycle
        self.onDelete = onDelete
        _weekCount = State(initialValue: cycle.weekCount)
        _principales = State(initialValue: Set(cycle.objectifsPrincipaux))
        _secondaires = State(initialValue: Set(cycle.objectifsSecondaires))
    }

    private var endDate: Date {
        Calendar.current.date(byAdding: .day, value: weekCount * 7, to: cycle.startDate) ?? cycle.startDate
    }

    private var canSave: Bool {
        !cycle.name.trimmingCharacters(in: .whitespaces).isEmpty && !principales.isEmpty
    }

    private var programMetrics: [ObjectiveMetricType] {
        guard let program = cycle.program else { return [] }
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
                        TextField("Cycle 2 — Reprise", text: $cycle.name)
                    }
                    DatePicker("Date de début", selection: $cycle.startDate, displayedComponents: .date)
                    Stepper("Durée : \(weekCount) semaine\(weekCount > 1 ? "s" : "")", value: $weekCount, in: 1...52)
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
                            Text(summaryLabel(principales)).foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                } header: {
                    Text("Qualités principales *")
                }

                Section {
                    NavigationLink {
                        QualitySelectionView(title: "Qualités secondaires", selection: $secondaires)
                    } label: {
                        HStack {
                            Text("Qualités secondaires")
                            Spacer()
                            Text(summaryLabel(secondaires)).foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                } header: {
                    Text("Qualités secondaires")
                }

                Section {
                    ForEach(cycle.sortedObjectives) { objective in
                        HStack {
                            Text(objective.summary)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Button {
                                context.delete(objective)
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

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Text("Supprimer le cycle")
                    }
                }
            }
            .navigationTitle("Modifier le cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminer") {
                        cycle.endDate = endDate
                        cycle.objectifsPrincipaux = Array(principales)
                        cycle.objectifsSecondaires = Array(secondaires)
                        // Une semaine retirée en réduisant la durée perd les séances déjà configurées dessus.
                        for session in cycle.trainingSessions where session.weekNumber > weekCount {
                            context.delete(session)
                        }
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingAddObjective) {
                AddObjectiveDraftView(allowedMetrics: programMetrics.isEmpty ? nil : programMetrics) { draft in
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
                        order: cycle.sortedObjectives.count
                    )
                    objective.cycle = cycle
                    context.insert(objective)
                }
            }
            .confirmationDialog(
                "Supprimer ce cycle ?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) {
                    context.delete(cycle)
                    onDelete()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Cette action est irréversible.")
            }
        }
    }

    private func summaryLabel(_ selection: Set<PhysicalQuality>) -> String {
        selection.isEmpty ? "Aucune" : selection.map(\.rawValue).joined(separator: ", ")
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
}
