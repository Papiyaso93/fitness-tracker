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
                Section {
                    TextField("Ex: Reprise, Affûtage", text: $name)
                } header: { formSectionHeader("Nom", required: true) }

                Section {
                    DatePicker(selection: $startDate, displayedComponents: .date) {
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
                } footer: {
                    Text("Qualité(s) à développer en priorité.")
                }

                Section {
                    NavigationLink {
                        QualitySelectionView(title: "Qualités secondaires", selection: $secondaires)
                    } label: {
                        qualitiesRow(secondaires)
                    }
                } header: {
                    formSectionHeader("Qualités secondaires")
                } footer: {
                    Text("Qualité(s) travaillée(s) en complément.")
                }

                Section {
                    ForEach(objectiveDrafts) { draft in
                        HStack {
                            objectiveDraftText(draft)
                            Spacer()
                            Button {
                                objectiveDrafts.removeAll { $0.id == draft.id }
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if objectiveDrafts.isEmpty {
                        addObjectiveRow(label: "Ajouter un objectif") { showingAddObjective = true }
                    }
                } header: {
                    sectionHeaderWithAdd("Objectifs du cycle", isEmpty: objectiveDrafts.isEmpty) { showingAddObjective = true }
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

    /// Stepper custom aux couleurs de l'app — le `.tint()` sur le `Stepper` natif ne teinte pas les
    /// boutons +/- de façon fiable dans un `Form`. Facilement réversible : remplacer ce bloc par
    /// `Stepper("Durée : \(weekCount) semaine(s)", value: $weekCount, in: 1...12)` restaure le natif.
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
                    if weekCount < 12 { weekCount += 1 }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 36, height: 30)
                        .contentShape(Rectangle())
                }
                .disabled(weekCount >= 12)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppTheme.accent)
            .background(AppTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .buttonStyle(.plain)
        }
    }

    private func summaryLabel(_ selection: Set<PhysicalQuality>) -> String {
        selection.isEmpty ? "Aucune" : selection.map(\.rawValue).joined(separator: ", ")
    }

    /// Une pastille par qualité (avec retour à la ligne), plutôt qu'une phrase concaténée qui wrap
    /// au milieu d'un mot dès qu'il y en a plusieurs.
    private func qualitiesRow(_ selection: Set<PhysicalQuality>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if selection.isEmpty {
                Text("Aucune")
                    .foregroundStyle(Color(hex: "B4AFA6"))
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(sortedQualities(selection), id: \.self) { quality in
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

    private func sortedQualities(_ selection: Set<PhysicalQuality>) -> [PhysicalQuality] {
        selection.sorted { $0.rawValue < $1.rawValue }
    }

    /// Ligne "Ajouter…" affichée tant qu'aucun objectif n'existe — une fois le premier ajouté,
    /// l'ajout suivant se fait via le "+" du header de Section, même pattern que Nouveau programme.
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

    private func objectiveDraftText(_ draft: ObjectiveDraft) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(draft.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            if let progressionText = draft.progressionText {
                Text(progressionText)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
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
        AppDateFormat.dayMonthYear.string(from: date)
    }
}
