import SwiftUI
import SwiftData

/// Équivalent de SessionDetailView (ancien système) pour une CycleSession du nouveau système —
/// même flow de saisie (Commencer/Ajouter/Terminer/Annuler pour la musculation, commentaire +
/// plan appliqué pour "Autre", "Autre séance réalisée ?" pour loguer un contenu différent du plan
/// sans le modifier).
struct LogCycleSessionView: View {
    @Bindable var session: CycleSession

    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss
    /// Relation `completion.setEntries` non fiable pour déclencher un refresh quand l'ajout se fait
    /// depuis une sheet enfant (même problème déjà rencontré sur ProgramDetailView/cycles) — on passe
    /// par un @Query filtré à la place.
    @Query private var allSetEntries: [PlannedSetEntry]
    @State private var isPlanExpanded = true
    @State private var showingAddSet = false
    @State private var editingSet: PlannedSetEntry?
    @State private var simpleComment: String = ""
    @State private var showingSwitchChoice = false

    private var scheduledDate: Date { session.scheduledDate ?? .now }
    private var isToday: Bool { Calendar.current.isDateInToday(scheduledDate) }
    private var isPast: Bool { scheduledDate < Calendar.current.startOfDay(for: .now) }
    private var isFuture: Bool { scheduledDate > Calendar.current.startOfDay(for: .now) && !isToday }

    /// Le type réellement en cours de saisie — celui du plan, sauf si une adaptation est en cours.
    private var effectiveKind: SessionKind {
        guard let completion = session.completion, completion.isAdapted else { return session.kind }
        return completion.adaptedKind ?? session.kind
    }

    private func entries(for completion: SessionCompletion) -> [PlannedSetEntry] {
        allSetEntries
            .filter { $0.completion?.id == completion.id }
            .sorted { $0.date < $1.date }
    }

    /// Hors programme : toujours quelque chose à supprimer (la séance elle-même). Planifiée :
    /// seulement s'il y a une saisie en cours à annuler — sinon rien à proposer.
    private var canCancelOrDelete: Bool {
        session.isAdHoc || session.completion != nil
    }

    private var cancelOrDeleteActionLabel: String {
        session.isAdHoc ? "Supprimer la séance" : "Annuler la séance"
    }

    var body: some View {
        List {
            if session.isAdHoc {
                adHocBadge.plainListRow(top: 0)
            }
            typeObjectiveCard.plainListRow(top: session.isAdHoc ? 12 : 0)
            if !session.isAdHoc {
                collapsibleHeader(text: "Plan de la séance").plainListRow(top: AppTheme.sectionSpacing)
                if isPlanExpanded {
                    planCard.plainListRow(top: 8)
                }
            }

            SectionLabel(text: "Ma séance").plainListRow(top: AppTheme.sectionSpacing)
            if hasSwitchSessionHeader {
                switchSessionHeader.plainListRow(top: 8)
            }
            if effectiveKind == .musculation {
                musculationSection
            } else {
                simpleSessionSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .contentMargins(.vertical, 16, for: .scrollContent)
        .background(AppTheme.background)
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canCancelOrDelete {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(cancelOrDeleteActionLabel, role: .destructive) {
                            cancelOrDeleteSession()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSet) {
            if let completion = session.completion {
                let suggested = (completion.isAdapted) ? [] : session.sortedExercises
                LogPlannedSetView(completion: completion, suggestedExercises: suggested)
            }
        }
        .sheet(item: $editingSet) { entry in
            EditPlannedSetEntryView(entry: entry)
        }
        .confirmationDialog("Quel type de séance ?", isPresented: $showingSwitchChoice) {
            Button("Musculation") { startAdaptation(kind: .musculation) }
            Button("Autre") { startAdaptation(kind: .autre) }
            Button("Annuler", role: .cancel) {}
        }
        .onAppear {
            simpleComment = session.completion?.simpleComment ?? ""
        }
    }

    private var adHocBadge: some View {
        Text("Hors programme")
            .font(.app(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.purple.opacity(0.15))
            .foregroundStyle(Color.purple.opacity(0.9))
            .clipShape(Capsule())
    }

    private var typeObjectiveCard: some View {
        AppCard {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(AppTheme.accent.opacity(0.12)).frame(width: 30, height: 30)
                    Image(systemName: session.kind.icon)
                        .font(.app(size: 14))
                        .foregroundStyle(AppTheme.accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.kind.rawValue)
                        .font(.app(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    if let objective = session.objective {
                        Text("Objectif : \(objective.rawValue)")
                            .font(.app(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var hasSwitchSessionHeader: Bool {
        session.completion?.isAdapted == true || (!session.isAdHoc && (isToday || isPast))
    }

    @ViewBuilder
    private var switchSessionHeader: some View {
        if session.completion?.isAdapted == true {
            HStack {
                Text("Séance adaptée")
                    .font(.app(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.yellow.opacity(0.2))
                    .foregroundStyle(Color(hex: "8A6D00"))
                    .clipShape(Capsule())
                Spacer()
                Button("Annuler") { cancelAdaptation() }
                .font(.app(size: 13))
            }
        } else if !session.isAdHoc && (isToday || isPast) {
            Button {
                showingSwitchChoice = true
            } label: {
                Text("Autre séance réalisée ?")
                    .underline()
            }
            .font(.app(size: 13))
            .foregroundStyle(AppTheme.textSecondary)
        }
    }

    /// Une seule action destructrice à la fois, jamais deux : pour une séance créée (hors
    /// programme), elle n'a pas de plan de référence donc "annuler" n'a pas de sens — on supprime
    /// carrément la séance. Pour une séance programmée, on garde la séance planifiée et on ne
    /// supprime que la saisie en cours.
    private func cancelOrDeleteSession() {
        if session.isAdHoc {
            context.delete(session)
            toast.showDeleted("Séance supprimée", context: context)
            dismiss()
        } else if let completion = session.completion {
            context.delete(completion)
            session.completion = nil
            toast.showDeleted("Saisie effacée", context: context)
        }
    }

    private func discardCurrentSession() {
        if let completion = session.completion {
            context.delete(completion)
            session.completion = nil
        }
        simpleComment = ""
    }

    private func startAdaptation(kind: SessionKind) {
        discardCurrentSession()
        let completion = SessionCompletion(startTime: .now, isAdapted: true, adaptedTitle: session.title, adaptedKind: kind)
        completion.cycleSession = session
        context.insert(completion)
        session.completion = completion
        toast.showDeleted("Séance adaptée", context: context)
    }

    private func cancelAdaptation() {
        discardCurrentSession()
        toast.showDeleted("Adaptation annulée", context: context)
    }

    private func collapsibleHeader(text: String) -> some View {
        Button {
            withAnimation { isPlanExpanded.toggle() }
        } label: {
            HStack {
                SectionLabel(text: text)
                Image(systemName: isPlanExpanded ? "chevron.up" : "chevron.down")
                    .font(.app(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var planCard: some View {
        if session.kind == .musculation {
            AppCard {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(session.sortedExercises.enumerated()), id: \.element.id) { index, exercise in
                        if index > 0 { Divider().overlay(AppTheme.border) }
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.app(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(width: 18, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                MuscleGroupTag(group: exercise.muscleGroup)
                                Text(exercise.exerciseName)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .fontWeight(.medium)
                                Text(exercise.summary)
                                    .font(.app(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                    }
                }
            }
        } else {
            AppCard {
                Text(session.sessionDescription?.isEmpty == false ? session.sessionDescription! : "Aucun plan renseigné")
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
    }

    // MARK: - Musculation

    @ViewBuilder
    private var musculationSection: some View {
        if let completion = session.completion {
            let entries = entries(for: completion)
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                Button {
                    editingSet = entry
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            MuscleGroupTag(group: entry.muscleGroup)
                            Text(entry.exerciseName)
                                .foregroundStyle(AppTheme.textPrimary)
                                .fontWeight(.medium)
                            Text(setSummary(entry))
                                .font(.app(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                            .font(.app(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppTheme.cardPadding)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(setRowBackground(isFirst: index == 0, isLast: index == entries.count - 1))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        context.delete(entry)
                        toast.showDeleted("Série supprimée", context: context)
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                    .tint(Color(hex: "E24B4A"))
                }
            }

            if completion.endTime == nil {
                Button {
                    showingAddSet = true
                } label: {
                    Text("Ajouter une série")
                        .primaryButtonStyle()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .plainListRow()

                Button {
                    completion.endTime = .now
                    toast.show(finishedMessage(for: completion)) { completion.endTime = nil }
                } label: {
                    Text("Terminer la séance")
                        .accentOutlineButtonStyle()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .plainListRow()
            } else {
                if let label = durationLabel(completion) {
                    Text(label)
                        .font(.app(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.secondary.opacity(0.15))
                        .foregroundStyle(Color(hex: "0F6E56"))
                        .clipShape(Capsule())
                        .plainListRow()
                }

                // Pas destructeur, contrairement à "Annuler" : remet juste la séance en cours (ce
                // qui réaffiche Ajouter une série/Terminer) sans toucher aux séries déjà loguées —
                // rattrape un tap accidentel sur "Terminer" sans perdre la saisie.
                Button {
                    completion.endTime = nil
                    toast.show("Séance rouverte")
                } label: {
                    Text("Rouvrir la séance")
                        .accentOutlineButtonStyle()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .plainListRow()
            }
        } else if isToday || isPast {
            Button {
                startSession()
            } label: {
                Text(isToday ? "Commencer la séance" : "Renseigner ma séance")
                    .primaryButtonStyle()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .plainListRow()
        } else {
            Text("Séance à venir.")
                .font(.app(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .plainListRow()
        }
    }

    /// Les séries sont des lignes natives de `List` (pour le balayage de suppression) mais gardent
    /// l'allure d'une seule carte : coins arrondis en haut de la première et en bas de la dernière.
    private func setRowBackground(isFirst: Bool, isLast: Bool) -> some View {
        let r = AppTheme.cardRadius
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: isFirst ? r : 0,
            bottomLeadingRadius: isLast ? r : 0,
            bottomTrailingRadius: isLast ? r : 0,
            topTrailingRadius: isFirst ? r : 0
        )
        return shape
            .fill(AppTheme.surface)
            .overlay(shape.stroke(AppTheme.border, lineWidth: 0.5))
    }

    private func setSummary(_ entry: PlannedSetEntry) -> String {
        // Au poids du corps, le poids de corps est déjà connu (c'est le mode lui-même) — l'afficher
        // n'apporte rien et alourdit la carte, contrairement aux autres modes où c'est la charge réelle.
        let weightLabel: String?
        switch entry.resistanceMode {
        case .poidsLibre, .machine, .elastique:
            weightLabel = entry.weight.map { "\(Int($0))kg" } ?? "—"
        case .poidsDuCorps:
            weightLabel = nil
        case .leste:
            // Comme pour le poids du corps, on n'affiche que la valeur qui progresse réellement
            // d'une séance à l'autre (le lest) — le poids de corps quasi constant n'apporte rien ici.
            weightLabel = entry.weight.map { "+\(Int($0))kg" } ?? "—"
        }
        let parts = [entry.resistanceMode.rawValue, weightLabel, "\(entry.reps) reps", entry.sensation.label].compactMap { $0 }
        return parts.joined(separator: " · ")
    }

    /// "Terminée · 52min" — uniquement pour la musculation, qui a un vrai début/fin séparés
    /// (Commencer/Terminer). Les séances "Autre" fixent les deux au même instant (pas d'étape
    /// "Commencer" séparée), donc une durée n'y aurait aucun sens.
    /// « Séance terminée · 38 min » (musculation) — la durée n'est affichée que si elle a un sens.
    private func finishedMessage(for completion: SessionCompletion) -> String {
        guard let start = completion.startTime, let end = completion.endTime else { return "Séance terminée" }
        let minutes = Int(end.timeIntervalSince(start) / 60)
        return minutes > 0 ? "Séance terminée · \(minutes) min" : "Séance terminée"
    }

    private func durationLabel(_ completion: SessionCompletion) -> String? {
        guard let start = completion.startTime, let end = completion.endTime else { return nil }
        let minutes = Int(end.timeIntervalSince(start) / 60)
        guard minutes > 0 else { return nil }
        return "Terminée · \(minutes)min"
    }

    private func startSession() {
        let completion = SessionCompletion(startTime: .now)
        completion.cycleSession = session
        context.insert(completion)
        session.completion = completion
        toast.show("Séance démarrée")
    }

    // MARK: - Autre

    @ViewBuilder
    private var simpleSessionSection: some View {
        if let completionEntry = session.completion, completionEntry.endTime != nil {
            AppCard {
                Text(completionEntry.simpleComment?.isEmpty == false ? completionEntry.simpleComment! : "Aucun commentaire")
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .plainListRow()
            Button {
                completionEntry.endTime = nil
                toast.show("Séance rouverte")
            } label: {
                Text("Rouvrir la séance")
                    .accentOutlineButtonStyle()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .plainListRow()
        } else if isToday || isPast {
            AppCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Commentaire").foregroundStyle(AppTheme.textSecondary).font(.app(size: 13))
                    TextField("Qu'as-tu fait ?", text: $simpleComment, axis: .vertical)
                }
            }
            .plainListRow()
            Button {
                saveSimpleSession()
            } label: {
                Text("Enregistrer la séance")
                    .primaryButtonStyle()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .plainListRow()
        } else {
            Text("Séance à venir.")
                .font(.app(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .plainListRow()
        }
    }

    private func saveSimpleSession() {
        // Une adaptation a déjà créé la SessionCompletion — on la complète plutôt que d'en créer
        // une seconde, sinon `isAdapted`/`adaptedKind` seraient perdus.
        if let completion = session.completion {
            completion.startTime = completion.startTime ?? .now
            completion.endTime = .now
            completion.simpleComment = simpleComment.isEmpty ? nil : simpleComment
        } else {
            let completion = SessionCompletion(
                startTime: .now,
                endTime: .now,
                simpleComment: simpleComment.isEmpty ? nil : simpleComment
            )
            completion.cycleSession = session
            context.insert(completion)
            session.completion = completion
        }
        toast.show("Séance enregistrée")
    }
}
