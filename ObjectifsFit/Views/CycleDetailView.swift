import SwiftUI
import SwiftData

/// Page de détail d'un cycle — infos, qualités, objectifs du cycle, et (à venir) la configuration
/// des semaines d'entraînement.
struct CycleDetailView: View {
    @Bindable var cycle: Cycle
    @Environment(\.dismiss) private var dismiss
    @Query private var allSessions: [CycleSession]

    @State private var showingEdit = false

    private func sessionsForWeek(_ week: Int) -> [CycleSession] {
        allSessions.filter { $0.cycle?.id == cycle.id && $0.weekNumber == week }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AppCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text("Du \(formatted(cycle.startDate)) au \(formatted(cycle.endDate))")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                        HStack {
                            Text(cycle.name)
                                .font(AppTheme.Font.cardTitle)
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            statusTag
                        }

                        if !cycle.objectifsPrincipaux.isEmpty {
                            qualityTags(cycle.objectifsPrincipaux, color: AppTheme.accent)
                        }
                        if !cycle.objectifsSecondaires.isEmpty {
                            qualityTags(cycle.objectifsSecondaires, color: AppTheme.textSecondary)
                        }
                    }
                }

                SectionLabel(text: "Objectifs du cycle")
                if cycle.sortedObjectives.isEmpty {
                    AppCard {
                        Text("Aucun objectif défini pour ce cycle.")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(cycle.sortedObjectives) { objective in
                            AppCard { objectiveRow(objective) }
                        }
                    }
                }

                SectionLabel(text: "Semaines")
                VStack(spacing: 10) {
                    ForEach(1...cycle.weekCount, id: \.self) { week in
                        NavigationLink {
                            WeekDetailView(cycle: cycle, weekNumber: week)
                        } label: {
                            weekRow(week)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.background)
        .navigationTitle("Cycle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Modifier") {
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditCycleView(cycle: cycle) {
                showingEdit = false
                dismiss()
            }
        }
    }

    private var statusTag: some View {
        let color: Color = {
            switch cycle.status {
            case .aVenir: return AppTheme.textSecondary
            case .enCours: return AppTheme.accent
            case .termine: return AppTheme.secondary
            }
        }()
        return Text(cycle.status.rawValue)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func objectiveRow(_ objective: ProgramObjective) -> some View {
        HStack {
            objectiveSummaryText(objective)
            Spacer(minLength: 0)
        }
    }

    /// Découpe "Nom : valeur" pour mettre le nom en gras et la valeur en dessous — même traitement
    /// neutre (pas de couleur d'accent sur la valeur) que la fiche programme.
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

    private func weekRow(_ week: Int) -> some View {
        let sessions = sessionsForWeek(week)
        return AppCard {
            HStack {
                Text("Semaine \(week)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(sessions.isEmpty ? "Vide" : "\(sessions.count) séance\(sessions.count > 1 ? "s" : "")")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private func qualityTags(_ qualities: [PhysicalQuality], color: Color) -> some View {
        HStack(spacing: 6) {
            ForEach(qualities) { quality in
                Text(quality.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
            }
        }
    }

    private func formatted(_ date: Date) -> String {
        AppDateFormat.dayMonthYear.string(from: date)
    }
}
