import SwiftUI
import SwiftData

struct ProgramDetailView: View {
    @Bindable var program: TrainingProgram
    @Environment(\.dismiss) private var dismiss
    @Query private var allCycles: [Cycle]

    @State private var showingCreateCycle = false
    @State private var showingEdit = false
    @State private var principalExpanded = false
    @State private var indicatorsExpanded = false

    /// Au-delà de ce nombre, la liste se replie derrière "Voir plus" — les objectifs principaux
    /// n'ont pas de limite stricte (juste une recommandation de 2), donc rien n'empêche d'en créer
    /// beaucoup, pareil pour les indicateurs qui peuvent facilement s'accumuler.
    private let collapsedObjectiveCount = 2

    private var sortedCycles: [Cycle] {
        let programID = program.id
        return allCycles
            .filter { $0.program?.id == programID }
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AppCard {
                    VStack(alignment: .leading, spacing: 6) {
                        if program.startDate != nil || program.endDate != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                Text(dateRangeLabel)
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(AppTheme.textSecondary)
                        }
                        HStack {
                            Text(program.title)
                                .font(AppTheme.Font.cardTitle)
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            statusTag
                        }
                        if let description = program.programDescription, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }

                objectivesSection(
                    title: "Objectifs principaux",
                    objectives: program.principalObjectives,
                    expanded: $principalExpanded,
                    emptyText: "Aucun objectif principal défini."
                )

                objectivesSection(
                    title: "Indicateurs à suivre",
                    objectives: program.secondaryObjectives,
                    expanded: $indicatorsExpanded,
                    emptyText: "Aucun indicateur défini."
                )

                SectionLabel(text: "Cycles")
                if sortedCycles.isEmpty {
                    AppCard {
                        Button {
                            showingCreateCycle = true
                        } label: {
                            HStack {
                                Text("Créer un nouveau cycle")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(sortedCycles) { cycle in
                            cycleRow(cycle)
                        }
                    }
                    Button {
                        showingCreateCycle = true
                    } label: {
                        Label("Créer un nouveau cycle", systemImage: "plus.circle")
                            .font(.system(size: 15, weight: .medium))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.background)
        .navigationTitle("Programme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Modifier") {
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingCreateCycle) {
            CreateCycleView(program: program)
        }
        .sheet(isPresented: $showingEdit) {
            EditProgramView(program: program) {
                showingEdit = false
                dismiss()
            }
        }
    }

    private var statusTag: some View {
        let color: Color = {
            switch program.status {
            case .aVenir: return AppTheme.textSecondary
            case .enCours: return AppTheme.accent
            case .termine: return AppTheme.secondary
            }
        }()
        return Text(program.status.rawValue)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var dateRangeLabel: String {
        switch (program.startDate, program.endDate) {
        case let (start?, end?): return "\(formatted(start)) → \(formatted(end))"
        case let (start?, nil): return "Depuis le \(formatted(start))"
        case let (nil, end?): return "Jusqu'au \(formatted(end))"
        default: return ""
        }
    }

    @ViewBuilder
    private func objectivesSection(title: String, objectives: [ProgramObjective], expanded: Binding<Bool>, emptyText: String) -> some View {
        SectionLabel(text: objectives.isEmpty ? title : "\(title) (\(objectives.count))")
        if objectives.isEmpty {
            AppCard {
                Text(emptyText)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        } else {
            let visible = expanded.wrappedValue ? objectives : Array(objectives.prefix(collapsedObjectiveCount))
            VStack(spacing: 10) {
                ForEach(visible) { objective in
                    AppCard { objectiveRow(objective) }
                }
            }
            if objectives.count > collapsedObjectiveCount {
                Button {
                    expanded.wrappedValue.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(expanded.wrappedValue ? "Voir moins" : "Voir plus")
                        Image(systemName: expanded.wrappedValue ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                }
                .padding(.top, 2)
            }
        }
    }

    private func objectiveRow(_ objective: ProgramObjective) -> some View {
        HStack {
            objectiveSummaryText(objective)
            Spacer(minLength: 0)
        }
    }

    /// Découpe "Nom : valeur" pour mettre le nom en gras et la valeur en dessous — même traitement
    /// neutre (pas de couleur d'accent sur la valeur) que la carte de brouillon en création.
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

    private func cycleRow(_ cycle: Cycle) -> some View {
        NavigationLink {
            CycleDetailView(cycle: cycle)
        } label: {
            AppCard {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(cycle.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("\(formatted(cycle.startDate)) → \(formatted(cycle.endDate))")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                        if !cycle.objectifsPrincipaux.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(cycle.objectifsPrincipaux) { quality in
                                    Text(quality.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(AppTheme.accent.opacity(0.12))
                                        .foregroundStyle(AppTheme.accent)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func formatted(_ date: Date) -> String {
        AppDateFormat.dayMonthYear.string(from: date)
    }
}
