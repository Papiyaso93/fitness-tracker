import SwiftUI
import SwiftData

/// Équivalent de SessionDetailView (ancien système) pour une CycleSession du nouveau système —
/// même flow de saisie (Commencer/Ajouter/Terminer/Annuler pour la musculation, commentaire +
/// plan appliqué pour "Autre", "Autre séance réalisée ?" pour loguer un contenu différent du plan
/// sans le modifier).
struct LogCycleSessionView: View {
    @Bindable var session: CycleSession

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// Relation `completion.setEntries` non fiable pour déclencher un refresh quand l'ajout se fait
    /// depuis une sheet enfant (même problème déjà rencontré sur ProgramDetailView/cycles) — on passe
    /// par un @Query filtré à la place.
    @Query private var allSetEntries: [PlannedSetEntry]
    @State private var isPlanExpanded = true
    @State private var showingAddSet = false
    @State private var editingSet: PlannedSetEntry?
    @State private var simpleComment: String = ""
    @State private var showingSwitchConfirm = false
    @State private var showingSwitchChoice = false
    @State private var showingCancelAdaptationConfirm = false

    private var scheduledDate: Date { session.scheduledDate ?? .now }
    private var isToday: Bool { Calendar.current.isDateInToday(scheduledDate) }
    private var isPast: Bool { scheduledDate < Calendar.current.startOfDay(for: .now) }
    private var isFuture: Bool { scheduledDate > Calendar.current.startOfDay(for: .now) && !isToday }

    /// Le type réellement en cours de saisie — celui du plan, sauf si une adaptation est en cours.
    private var effectiveKind: SessionKind {
        guard let completion = session.completion, completion.isAdapted else { return session.kind }
        return completion.adaptedKind ?? session.kind
    }

    private var hasEnteredData: Bool {
        guard let completion = session.completion else { return false }
        return completion.startTime != nil || completion.endTime != nil || !entries(for: completion).isEmpty
            || !(completion.simpleComment?.isEmpty ?? true)
    }

    private func entries(for completion: SessionCompletion) -> [PlannedSetEntry] {
        allSetEntries
            .filter { $0.completion?.id == completion.id }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if session.isAdHoc {
                    adHocBadge
                }
                typeObjectiveCard
                if !session.isAdHoc {
                    collapsibleHeader(text: "Plan de la séance")
                    if isPlanExpanded {
                        planCard
                    }
                }

                SectionLabel(text: "Ma séance")
                switchSessionHeader
                if effectiveKind == .musculation {
                    musculationSection
                } else {
                    simpleSessionSection
                }

            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddSet) {
            if let completion = session.completion {
                let suggested = (completion.isAdapted) ? [] : session.sortedExercises
                LogPlannedSetView(completion: completion, suggestedExercises: suggested)
            }
        }
        .sheet(item: $editingSet) { entry in
            EditPlannedSetEntryView(entry: entry)
        }
        .confirmationDialog(
            "Les informations déjà saisies pour cette séance seront perdues.",
            isPresented: $showingSwitchConfirm,
            titleVisibility: .visible
        ) {
            Button("Continuer", role: .destructive) {
                discardCurrentSession()
                showingSwitchChoice = true
            }
            Button("Annuler", role: .cancel) {}
        }
        .confirmationDialog("Quel type de séance ?", isPresented: $showingSwitchChoice) {
            Button("Musculation") { startAdaptation(kind: .musculation) }
            Button("Autre") { startAdaptation(kind: .autre) }
            Button("Annuler", role: .cancel) {}
        }
        .confirmationDialog(
            "Les informations déjà saisies pour cette séance seront perdues.",
            isPresented: $showingCancelAdaptationConfirm,
            titleVisibility: .visible
        ) {
            Button("Continuer", role: .destructive) { discardCurrentSession() }
            Button("Annuler", role: .cancel) {}
        }
        .onAppear {
            simpleComment = session.completion?.simpleComment ?? ""
        }
    }

    private var adHocBadge: some View {
        Text("Hors programme")
            .font(.system(size: 11, weight: .medium))
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
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.kind.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    if let objective = session.objective {
                        Text("Objectif : \(objective.rawValue)")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var switchSessionHeader: some View {
        if session.completion?.isAdapted == true {
            HStack {
                Text("Séance adaptée")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.yellow.opacity(0.2))
                    .foregroundStyle(Color(hex: "8A6D00"))
                    .clipShape(Capsule())
                Spacer()
                Button("Annuler") {
                    if hasEnteredData {
                        showingCancelAdaptationConfirm = true
                    } else {
                        discardCurrentSession()
                    }
                }
                .font(.system(size: 13))
            }
        } else if !session.isAdHoc && (isToday || isPast) {
            Button {
                if hasEnteredData {
                    showingSwitchConfirm = true
                } else {
                    showingSwitchChoice = true
                }
            } label: {
                Text("Autre séance réalisée ?")
                    .underline()
            }
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textSecondary)
        }
    }

    /// Une seule action destructrice à la fois, jamais deux : pour une séance créée (hors
    /// programme), elle n'a pas de plan de référence donc "annuler" n'a pas de sens — on supprime
    /// carrément la séance. Pour une séance programmée, on garde la séance planifiée et on ne
    /// supprime que la saisie en cours.
    private var cancelOrDeleteButton: some View {
        Button(session.isAdHoc ? "Supprimer la séance" : "Annuler la séance", role: .destructive) {
            cancelOrDeleteSession()
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity)
    }

    private func cancelOrDeleteSession() {
        if session.isAdHoc {
            context.delete(session)
            dismiss()
        } else if let completion = session.completion {
            context.delete(completion)
            session.completion = nil
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
        let completion = SessionCompletion(startTime: .now, isAdapted: true, adaptedTitle: session.title, adaptedKind: kind)
        completion.cycleSession = session
        context.insert(completion)
        session.completion = completion
    }

    private func collapsibleHeader(text: String) -> some View {
        Button {
            withAnimation { isPlanExpanded.toggle() }
        } label: {
            HStack {
                SectionLabel(text: text)
                Image(systemName: isPlanExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11))
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
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(width: 18, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                MuscleGroupTag(group: exercise.muscleGroup)
                                Text(exercise.exerciseName)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .fontWeight(.medium)
                                Text(exercise.summary)
                                    .font(.system(size: 12))
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
            if !entries.isEmpty {
                AppCard {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 { Divider().overlay(AppTheme.border) }
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
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    Spacer(minLength: 0)
                                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if completion.endTime == nil {
                Button {
                    showingAddSet = true
                } label: {
                    Text("Ajouter une série")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    completion.endTime = .now
                } label: {
                    Text("Terminer la séance")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                                .stroke(AppTheme.accent, lineWidth: 1.5)
                        )
                        .foregroundStyle(AppTheme.accent)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                cancelOrDeleteButton
            } else {
                cancelOrDeleteButton
            }
        } else if isToday || isPast {
            Button {
                startSession()
            } label: {
                Text(isToday ? "Commencer la séance" : "Renseigner ma séance")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if session.isAdHoc {
                cancelOrDeleteButton
            }
        } else {
            Text("Séance à venir.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
        }
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

    private func startSession() {
        let completion = SessionCompletion(startTime: .now)
        completion.cycleSession = session
        context.insert(completion)
        session.completion = completion
    }

    // MARK: - Autre

    @ViewBuilder
    private var simpleSessionSection: some View {
        if let completionEntry = session.completion, completionEntry.endTime != nil {
            AppCard {
                Text(completionEntry.simpleComment?.isEmpty == false ? completionEntry.simpleComment! : "Aucun commentaire")
                    .foregroundStyle(AppTheme.textPrimary)
            }
            cancelOrDeleteButton
        } else if isToday || isPast {
            AppCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Commentaire").foregroundStyle(AppTheme.textSecondary).font(.system(size: 13))
                    TextField("Qu'as-tu fait ?", text: $simpleComment, axis: .vertical)
                }
            }
            Button {
                saveSimpleSession()
            } label: {
                Text("Enregistrer la séance")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if session.isAdHoc {
                cancelOrDeleteButton
            }
        } else {
            Text("Séance à venir.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
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
    }
}
