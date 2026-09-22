import SwiftUI
import SwiftData

/// Édition d'une moitié de journée déjà renseignée — même pattern que TransitDetailView/MealDetailView :
/// poussé (pas une sheet), champs branchés en direct sur le modèle, pas de bouton "Enregistrer".
struct SleepDetailView: View {
    @Bindable var log: SleepLog
    let moment: SleepMoment

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allSleepLogs: [SleepLog]

    /// Bandeau affiché quand l'heure de coucher bascule automatiquement vers la veille.
    private var rollbackNotice: String? {
        guard moment == .coucher, let time = log.bedTime, Calendar.current.component(.hour, from: time) < 12 else { return nil }
        let target = moment.targetDay(for: time)
        return "Cette heure sera rattachée à la nuit du \(AppDateFormat.dayFullMonth.string(from: target))."
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { (moment == .reveil ? log.wakeTime : log.bedTime) ?? .now },
            set: { if moment == .reveil { log.wakeTime = $0 } else { log.bedTime = $0 } }
        )
    }

    private var energyBinding: Binding<EnergyLevel> {
        Binding(
            get: { (moment == .reveil ? log.wakeEnergy : log.bedEnergy) ?? .normal },
            set: { if moment == .reveil { log.wakeEnergy = $0 } else { log.bedEnergy = $0 } }
        )
    }

    private var stomachBinding: Binding<StomachState> {
        Binding(
            get: { (moment == .reveil ? log.wakeStomach : log.bedStomach) ?? .neutre },
            set: { if moment == .reveil { log.wakeStomach = $0 } else { log.bedStomach = $0 } }
        )
    }

    var body: some View {
        Form {
            Section {
                DatePicker(moment.timeLabel, selection: timeBinding, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                if let rollbackNotice {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                        Text(rollbackNotice)
                            .font(.system(size: 12.5))
                    }
                    .foregroundStyle(Color(hex: "993C1D"))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } header: { formSectionHeader(moment.timeLabel, required: true) }

            Section {
                AppMenuField(
                    label: "État de forme",
                    options: EnergyLevel.allCases.map { ($0, $0.label) },
                    selection: energyBinding,
                    required: true,
                    showsLabel: false
                )
            } header: { formSectionHeader("État de forme", required: true) }

            Section {
                AppMenuField(
                    label: "État du ventre",
                    options: StomachState.allCases.map { ($0, $0.label) },
                    selection: stomachBinding,
                    required: true,
                    showsLabel: false
                )
            } header: { formSectionHeader("État du ventre", required: true) }

            Section {
                Button("Supprimer ce \(moment.title.lowercased())", role: .destructive) {
                    clearMoment()
                }
            }
        }
        .navigationTitle(moment.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { reconcileDayIfNeeded() }
    }

    /// Si la date choisie dans le picker retombe sur un autre jour que `log.day`, l'entrée reste
    /// mal rangée tant qu'on ne la déplace pas : on le fait à la sortie de l'écran plutôt qu'à
    /// chaque frappe (éviter de fragmenter l'enregistrement pendant que l'utilisateur ajuste
    /// l'heure). Si l'autre moment du log est vide, on renomme simplement le jour du log ; sinon
    /// on transfère seulement ce moment vers le `SleepLog` du jour cible (existant ou créé).
    private func reconcileDayIfNeeded() {
        let time = moment == .reveil ? log.wakeTime : log.bedTime
        guard let time else { return }
        let targetDay = moment.targetDay(for: time)
        guard !Calendar.current.isDate(targetDay, inSameDayAs: log.day) else { return }

        let otherMomentFilled: Bool
        switch moment {
        case .reveil: otherMomentFilled = log.bedTime != nil
        case .coucher: otherMomentFilled = log.wakeTime != nil
        }

        if !otherMomentFilled {
            log.day = targetDay
            return
        }

        let target = allSleepLogs.first { $0.id != log.id && Calendar.current.isDate($0.day, inSameDayAs: targetDay) }
            ?? {
                let newLog = SleepLog(day: targetDay)
                context.insert(newLog)
                return newLog
            }()

        switch moment {
        case .reveil:
            target.wakeTime = log.wakeTime
            target.wakeEnergy = log.wakeEnergy
            target.wakeStomach = log.wakeStomach
            log.wakeTime = nil
            log.wakeEnergy = nil
            log.wakeStomach = nil
        case .coucher:
            target.bedTime = log.bedTime
            target.bedEnergy = log.bedEnergy
            target.bedStomach = log.bedStomach
            log.bedTime = nil
            log.bedEnergy = nil
            log.bedStomach = nil
        }
    }

    private func clearMoment() {
        switch moment {
        case .reveil:
            log.wakeTime = nil
            log.wakeEnergy = nil
            log.wakeStomach = nil
        case .coucher:
            log.bedTime = nil
            log.bedEnergy = nil
            log.bedStomach = nil
        }
        if log.wakeTime == nil && log.bedTime == nil {
            context.delete(log)
        }
        dismiss()
    }
}
