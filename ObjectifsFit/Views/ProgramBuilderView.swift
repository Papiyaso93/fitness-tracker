import SwiftUI
import SwiftData

/// Constructeur de programme générique (Programme/Cycle/CycleSession).
struct ProgramBuilderView: View {
    @Query private var programs: [TrainingProgram]

    @State private var showingCreateSheet = false

    private var sortedPrograms: [TrainingProgram] {
        func statusRank(_ status: ProgramStatus) -> Int {
            switch status {
            case .enCours: return 0
            case .aVenir: return 1
            case .termine: return 2
            }
        }
        return programs.sorted { lhs, rhs in
            let lhsRank = statusRank(lhs.status)
            let rhsRank = statusRank(rhs.status)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return (lhs.startDate ?? .distantFuture) < (rhs.startDate ?? .distantFuture)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if sortedPrograms.isEmpty {
                        emptyState
                    } else {
                        SectionLabel(text: "Programmes")
                        VStack(spacing: 10) {
                            ForEach(sortedPrograms) { program in
                                NavigationLink {
                                    ProgramDetailView(program: program)
                                } label: {
                                    programRow(program)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button {
                            showingCreateSheet = true
                        } label: {
                            Label("Créer un nouveau programme", systemImage: "plus.circle")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppTheme.background)
            .navigationTitle("Programme")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateProgramView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("📋")
                .font(.system(size: 36))
            Text("Aucun programme pour l'instant")
                .font(AppTheme.Font.cardTitle)
                .foregroundStyle(AppTheme.textPrimary)
            Text("Un programme porte un ou plusieurs objectifs à long terme et se compose d'un ou plusieurs cycles.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                showingCreateSheet = true
            } label: {
                Text("Créer mon programme")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func programRow(_ program: TrainingProgram) -> some View {
        AppCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppTheme.accent.opacity(0.12)).frame(width: 40, height: 40)
                    Image(systemName: "target")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(program.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    ForEach(program.principalObjectives) { objective in
                        Text(objective.summary)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                    if let dateRangeLabel = dateRangeLabel(program) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                            Text(dateRangeLabel)
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    statusTag(program.status)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private func dateRangeLabel(_ program: TrainingProgram) -> String? {
        switch (program.startDate, program.endDate) {
        case let (start?, end?): return "\(formatted(start)) → \(formatted(end))"
        case let (start?, nil): return "Depuis le \(formatted(start))"
        case let (nil, end?): return "Jusqu'au \(formatted(end))"
        default: return nil
        }
    }

    private func formatted(_ date: Date) -> String {
        AppDateFormat.dayMonthYear.string(from: date)
    }

    private func statusTag(_ status: ProgramStatus) -> some View {
        let color: Color = {
            switch status {
            case .aVenir: return AppTheme.textSecondary
            case .enCours: return AppTheme.accent
            case .termine: return .green
            }
        }()
        return Text(status.rawValue)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
