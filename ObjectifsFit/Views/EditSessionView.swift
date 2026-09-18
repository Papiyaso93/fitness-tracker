import SwiftUI
import SwiftData

/// Création ou édition d'une séance planifiée (titre, type, objectif, puis contenu selon le type).
struct EditSessionView: View {
    private let existingSession: CycleSession?
    private let cycle: Cycle
    private let weekNumber: Int
    private let order: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var weekday: Int
    @State private var title: String
    @State private var kind: SessionKind
    @State private var objective: PhysicalQuality?
    @State private var sessionDescription: String
    @State private var exerciseDrafts: [PlannedExerciseDraft]
    @State private var showingAddExercise = false
    @State private var showingDeleteConfirmation = false

    /// Création d'une nouvelle séance.
    init(cycle: Cycle, weekNumber: Int, weekday: Int, order: Int) {
        self.existingSession = nil
        self.cycle = cycle
        self.weekNumber = weekNumber
        self.order = order
        _weekday = State(initialValue: weekday)
        _title = State(initialValue: "")
        _kind = State(initialValue: .musculation)
        _objective = State(initialValue: nil)
        _sessionDescription = State(initialValue: "")
        _exerciseDrafts = State(initialValue: [])
    }

    /// Édition d'une séance existante.
    init(session: CycleSession) {
        self.existingSession = session
        self.cycle = session.cycle!
        self.weekNumber = session.weekNumber
        self.order = session.order
        _weekday = State(initialValue: session.weekday)
        _title = State(initialValue: session.title)
        _kind = State(initialValue: session.kind)
        _objective = State(initialValue: session.objective)
        _sessionDescription = State(initialValue: session.sessionDescription ?? "")
        _exerciseDrafts = State(initialValue: session.sortedExercises.map { exercise in
            var draft = PlannedExerciseDraft()
            draft.muscleGroup = exercise.muscleGroup
            draft.exerciseName = exercise.exerciseName
            draft.technique = exercise.technique
            draft.resistanceMode = exercise.resistanceMode
            draft.targetSets = String(exercise.targetSets)
            draft.targetWeight = exercise.targetWeight.map { $0.formatted() } ?? ""
            draft.isRepsRange = exercise.isRepsRange
            draft.targetRepsMin = String(exercise.targetRepsMin)
            draft.targetRepsMax = String(exercise.targetRepsMax)
            return draft
        })
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && objective != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Jour", selection: $weekday) {
                        ForEach(Weekday.ordered, id: \.weekday) { day in
                            Text(day.label).tag(day.weekday)
                        }
                    }
                } header: { formSectionHeader("Jour", required: true) }

                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(SessionKind.allCases) { k in
                            Text(k.rawValue).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: { formSectionHeader("Type", required: true) }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        fieldCaption("Titre", required: true)
                        TextField("Ex: Push, Plyo, Cardio seuil…", text: $title)
                    }
                }

                Section {
                    Picker("Objectif", selection: $objective) {
                        Text("Choisir…").tag(PhysicalQuality?.none)
                        ForEach(PhysicalQuality.allCasesSortedAlphabetically) { quality in
                            Text(quality.rawValue).tag(PhysicalQuality?.some(quality))
                        }
                    }
                } header: { formSectionHeader("Objectif de la séance", required: true) }

                if kind == .autre {
                    Section {
                        TextField("Plan de la séance", text: $sessionDescription, axis: .vertical)
                    } header: { formSectionHeader("Plan de la séance") }
                } else {
                    Section {
                        ForEach(exerciseDrafts) { draft in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\((exerciseDrafts.firstIndex(where: { $0.id == draft.id }) ?? 0) + 1)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .frame(width: 16, alignment: .leading)
                                VStack(alignment: .leading, spacing: 4) {
                                    if !draft.muscleGroup.isEmpty {
                                        MuscleGroupTag(group: draft.muscleGroup)
                                    }
                                    Text(draft.exerciseName)
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .fontWeight(.medium)
                                    Text(draft.summary)
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer(minLength: 0)
                                Button {
                                    exerciseDrafts.removeAll { $0.id == draft.id }
                                } label: {
                                    Image(systemName: "trash").foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 6)
                        }
                        .onMove { source, destination in
                            exerciseDrafts.move(fromOffsets: source, toOffset: destination)
                        }
                        Button {
                            showingAddExercise = true
                        } label: {
                            Label("Ajouter un exercice", systemImage: "plus.circle")
                        }
                    } header: {
                        HStack {
                            formSectionHeader("Plan de la séance")
                            Spacer()
                            if exerciseDrafts.count > 1 {
                                EditButton()
                                    .font(.system(size: 12))
                                    .textCase(nil)
                            }
                        }
                    }
                }

                if existingSession != nil {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Text("Supprimer cette séance")
                        }
                    }
                }
            }
            .navigationTitle(existingSession == nil ? "Nouvelle séance" : "Modifier la séance")
            .navigationBarTitleDisplayMode(existingSession == nil ? .large : .inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingSession == nil ? "Créer" : "Enregistrer") { save() }
                        .disabled(!canSave)
                }
            }
            .confirmationDialog(
                "Supprimer cette séance ?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) {
                    if let existingSession {
                        context.delete(existingSession)
                    }
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            }
            .sheet(isPresented: $showingAddExercise) {
                AddPlannedExerciseView { draft in
                    exerciseDrafts.append(draft)
                }
            }
        }
    }

    private func save() {
        let session: CycleSession
        if let existingSession {
            session = existingSession
            session.title = title.trimmingCharacters(in: .whitespaces)
            session.kind = kind
            session.objective = objective
            session.sessionDescription = kind == .autre ? sessionDescription : nil
            for exercise in session.exercises {
                context.delete(exercise)
            }
        } else {
            session = CycleSession(
                weekNumber: weekNumber,
                weekday: weekday,
                title: title.trimmingCharacters(in: .whitespaces),
                kind: kind,
                objective: objective,
                sessionDescription: kind == .autre ? sessionDescription : nil,
                order: order
            )
            session.cycle = cycle
            context.insert(session)
        }

        if kind == .musculation {
            for (index, draft) in exerciseDrafts.enumerated() {
                let exercise = PlannedExercise(
                    muscleGroup: draft.muscleGroup,
                    exerciseName: draft.exerciseName,
                    technique: draft.technique,
                    resistanceMode: draft.resistanceMode,
                    targetSets: Int(draft.targetSets) ?? 0,
                    targetWeight: Double(draft.targetWeight),
                    isRepsRange: draft.isRepsRange,
                    targetRepsMin: Int(draft.targetRepsMin) ?? 0,
                    targetRepsMax: Int(draft.targetRepsMax) ?? (Int(draft.targetRepsMin) ?? 0),
                    order: index
                )
                exercise.session = session
                context.insert(exercise)
            }
        }

        dismiss()
    }
}
