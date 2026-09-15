import SwiftUI
import SwiftData

struct ProgramDetailView: View {
    @Bindable var program: TrainingProgram
    @Environment(\.dismiss) private var dismiss
    @Query private var allCycles: [Cycle]

    @State private var showingCreateCycle = false
    @State private var showingEdit = false

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
                    VStack(alignment: .leading, spacing: 8) {
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
                        if program.startDate != nil || program.endDate != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                Text(dateRangeLabel)
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.top, 4)
                            .overlay(alignment: .top) {
                                Rectangle().fill(AppTheme.border).frame(height: 0.5)
                            }
                        }
                    }
                }

                SectionLabel(text: "Objectifs principaux")
                if program.principalObjectives.isEmpty {
                    AppCard {
                        Text("Aucun objectif principal défini.")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else {
                    AppCard {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(program.principalObjectives.enumerated()), id: \.element.id) { index, objective in
                                if index > 0 {
                                    Divider().overlay(AppTheme.border)
                                }
                                objectiveRow(objective, icon: "target", iconColor: AppTheme.accent, valueColor: AppTheme.accent)
                            }
                        }
                    }
                }

                SectionLabel(text: "Indicateurs à suivre")
                if program.secondaryObjectives.isEmpty {
                    AppCard {
                        Text("Aucun indicateur défini.")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else {
                    AppCard {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(program.secondaryObjectives.enumerated()), id: \.element.id) { index, objective in
                                if index > 0 {
                                    Divider().overlay(AppTheme.border)
                                }
                                indicatorRow(objective)
                            }
                        }
                    }
                }

                SectionLabel(text: "Cycles")
                if sortedCycles.isEmpty {
                    AppCard {
                        Text("Aucun cycle pour l'instant.")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(sortedCycles) { cycle in
                            cycleRow(cycle)
                        }
                    }
                }

                Button {
                    showingCreateCycle = true
                } label: {
                    Label("Créer un nouveau cycle", systemImage: "plus.circle")
                        .font(.system(size: 15, weight: .medium))
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
            case .termine: return .green
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

    private func objectiveRow(_ objective: ProgramObjective, icon: String, iconColor: Color, valueColor: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(iconColor.opacity(0.12)).frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            objectiveSummaryText(objective, valueColor: valueColor)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    private func indicatorRow(_ objective: ProgramObjective) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: objective.isMeasurable ? "ruler" : "note.text")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 26, alignment: .center)
            Text(objective.summary)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    /// Découpe "Nom : valeur" pour mettre le nom en gras et la valeur en couleur d'accent, sur deux lignes.
    private func objectiveSummaryText(_ objective: ProgramObjective, valueColor: Color) -> some View {
        let parts = objective.summary.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        return VStack(alignment: .leading, spacing: 2) {
            if parts.count == 2 {
                Text(parts[0]).font(.system(size: 13, weight: .medium)).foregroundStyle(AppTheme.textPrimary)
                Text(parts[1]).font(.system(size: 13, weight: .medium)).foregroundStyle(valueColor)
            } else {
                Text(objective.summary)
                    .font(.system(size: 13, weight: .medium))
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
