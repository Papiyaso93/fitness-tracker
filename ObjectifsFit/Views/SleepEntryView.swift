import SwiftUI
import SwiftData

enum SleepMoment: Identifiable {
    case reveil
    case coucher

    var id: Self { self }

    var title: String {
        switch self {
        case .reveil: return "Réveil"
        case .coucher: return "Coucher"
        }
    }

    var timeLabel: String {
        switch self {
        case .reveil: return "Heure de réveil"
        case .coucher: return "Heure de coucher"
        }
    }

    var defaultHour: Int {
        switch self {
        case .reveil: return 7
        case .coucher: return 22
        }
    }
}

/// Création d'une moitié de journée pas encore renseignée — rattachée au `SleepLog` du jour
/// concerné, créé à la volée s'il n'existe pas encore (ex: premier des deux moments renseignés).
/// Une fois renseignée, l'édition se fait via `SleepDetailView` (mêmes règles que Repas/Transit).
struct SleepEntryView: View {
    let day: Date
    let moment: SleepMoment

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allSleepLogs: [SleepLog]

    @State private var time: Date
    @State private var energy: EnergyLevel = .normal
    @State private var stomach: StomachState = .neutre

    init(day: Date, moment: SleepMoment) {
        self.day = day
        self.moment = moment
        _time = State(initialValue: Calendar.current.date(bySettingHour: moment.defaultHour, minute: 0, second: 0, of: day) ?? day)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(moment.timeLabel, selection: $time, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                } header: { formSectionHeader(moment.timeLabel, required: true) }

                Section {
                    AppMenuField(
                        label: "État de forme",
                        options: EnergyLevel.allCases.map { ($0, $0.label) },
                        selection: $energy,
                        required: true,
                        showsLabel: false
                    )
                } header: { formSectionHeader("État de forme", required: true) }

                Section {
                    AppMenuField(
                        label: "État du ventre",
                        options: StomachState.allCases.map { ($0, $0.label) },
                        selection: $stomach,
                        required: true,
                        showsLabel: false
                    )
                } header: { formSectionHeader("État du ventre", required: true) }
            }
            .navigationTitle(moment.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                }
            }
        }
    }

    /// La date choisie dans le picker peut différer de `day` (ouverture depuis un autre jour que
    /// celui du formulaire) — on recible toujours vers le `SleepLog` du jour réellement sélectionné,
    /// pas celui d'origine, pour permettre de renseigner un jour passé en le changeant ici.
    private func save() {
        let targetDay = Calendar.current.startOfDay(for: time)
        let log: SleepLog
        if let found = allSleepLogs.first(where: { Calendar.current.isDate($0.day, inSameDayAs: targetDay) }) {
            log = found
        } else {
            log = SleepLog(day: targetDay)
            context.insert(log)
        }
        switch moment {
        case .reveil:
            log.wakeTime = time
            log.wakeEnergy = energy
            log.wakeStomach = stomach
        case .coucher:
            log.bedTime = time
            log.bedEnergy = energy
            log.bedStomach = stomach
        }
        dismiss()
    }
}
