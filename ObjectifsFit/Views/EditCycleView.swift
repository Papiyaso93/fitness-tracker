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
                Section {
                    TextField("Ex: Reprise, Affûtage", text: $cycle.name)
                } header: { formSectionHeader("Nom", required: true) }

                Section {
                    DatePicker(selection: $cycle.startDate, displayedComponents: .date) {
                        fieldLabel("Date de début")
                    }
                    durationRow
                } header: {
                    formSectionHeader("Période", required: true)
                } footer: {
                    Text("Se termine le \(formatted(endDate)).")
                }

                Section {
                    NavigationLink {
                        QualitySelectionView(title: "Qualités principales", selection: $principales)
                    } label: {
                        qualitiesRow(principales)
                    }
                } header: {
                    formSectionHeader("Qualités principales", required: true)
                }

                Section {
                    NavigationLink {
                        QualitySelectionView(title: "Qualités secondaires", selection: $secondaires)
                    } label: {
                        qualitiesRow(secondaires)
                    }
                } header: {
                    formSectionHeader("Qualités secondaires")
                }

                Section {
                    ForEach(cycle.sortedObjectives) { objective in
                        HStack {
                            objectiveSummaryText(objective)
                            Spacer()
                            Button {
                                context.delete(objective)
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if cycle.sortedObjectives.isEmpty {
                        addObjectiveRow(label: "Ajouter un objectif") { showingAddObjective = true }
                    }
                } header: {
                    sectionHeaderWithAdd("Objectifs du cycle", isEmpty: cycle.sortedObjectives.isEmpty) { showingAddObjective = true }
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

    /// Une pastille par qualité (avec retour à la ligne), même traitement que Nouveau cycle.
    private func qualitiesRow(_ selection: Set<PhysicalQuality>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if selection.isEmpty {
                Text("Aucune")
                    .foregroundStyle(Color(hex: "B4AFA6"))
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(selection.sorted { $0.rawValue < $1.rawValue }, id: \.self) { quality in
                        Text(quality.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.accent.opacity(0.1))
                            .foregroundStyle(Color(hex: "993C1D"))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Stepper custom aux couleurs de l'app, même traitement que Nouveau cycle.
    private var durationRow: some View {
        HStack {
            Text("Durée : \(weekCount) semaine\(weekCount > 1 ? "s" : "")")
            Spacer()
            HStack(spacing: 0) {
                Button {
                    if weekCount > 1 { weekCount -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 36, height: 30)
                        .contentShape(Rectangle())
                }
                .disabled(weekCount <= 1)
                Divider().frame(height: 18)
                Button {
                    if weekCount < 52 { weekCount += 1 }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 36, height: 30)
                        .contentShape(Rectangle())
                }
                .disabled(weekCount >= 52)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppTheme.accent)
            .background(AppTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .buttonStyle(.plain)
        }
    }

    /// Ligne "Ajouter…" affichée tant qu'aucun objectif n'existe — une fois le premier ajouté,
    /// l'ajout suivant se fait via le "+" du header de Section, même pattern que Nouveau cycle.
    private func addObjectiveRow(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .buttonStyle(.plain)
    }

    private func sectionHeaderWithAdd(_ title: String, isEmpty: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            formSectionHeader(title)
            Spacer()
            if !isEmpty {
                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .padding(.bottom, 6)
    }

    /// Découpe "Nom : valeur" pour mettre le nom en gras et la valeur en dessous — même traitement
    /// que la fiche programme.
    private func objectiveSummaryText(_ objective: ProgramObjective) -> some View {
        let parts = objective.summary.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        return VStack(alignment: .leading, spacing: 2) {
            if parts.count == 2 {
                Text(parts[0]).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppTheme.textPrimary)
                Text(parts[1]).font(.system(size: 13)).foregroundStyle(AppTheme.textSecondary)
            } else {
                Text(objective.summary)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
    }

    private func formatted(_ date: Date) -> String {
        AppDateFormat.dayMonthYear.string(from: date)
    }
}
