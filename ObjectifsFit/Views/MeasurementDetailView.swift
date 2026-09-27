import SwiftUI
import SwiftData
import Charts

/// Historique + tendance d'un type de mesure (poids, tour de taille, VO2max...) — se relie
/// automatiquement à un objectif chiffré existant sur ce même type (programme ou cycle) pour
/// afficher la cible, sans dupliquer la donnée entre "objectifs" et "mesures loguées".
struct MeasurementDetailView: View {
    let type: ObjectiveMetricType

    @Query private var allEntries: [BodyMeasurementEntry]
    @Query private var allObjectives: [ProgramObjective]
    @Environment(\.modelContext) private var context

    private var entries: [BodyMeasurementEntry] {
        allEntries.filter { $0.type == type }.sorted { $0.date > $1.date }
    }

    private var matchingObjective: ProgramObjective? {
        allObjectives.first { $0.isMeasurable && $0.metricType == type && $0.targetValue != nil }
    }

    private func formattedValue(_ value: Double) -> String {
        "\(value.formatted())\(type.unit.isEmpty ? "" : type.unit)"
    }

    private var previousEntry: BodyMeasurementEntry? {
        entries.count > 1 ? entries[1] : nil
    }

    /// Pourcentage du chemin parcouru entre la valeur de départ de l'objectif et sa cible — nil
    /// tant que l'objectif n'est pas un objectif de progression avec un départ et une cible.
    private var objectiveProgress: Double? {
        guard let objective = matchingObjective, objective.mode == .progression,
              let start = objective.startValue, let target = objective.targetValue, target != start,
              let current = entries.first?.value
        else { return nil }
        return min(1, max(0, (current - start) / (target - start)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppCard {
                    StatTile(
                        label: type.rawValue,
                        value: entries.first.map { formattedValue($0.value) } ?? "—",
                        target: matchingObjective?.targetValue.map { "\($0.formatted())\(type.unit)" }
                    )
                    if let first = entries.first, let previousEntry {
                        progressionPill(current: first, previous: previousEntry)
                            .padding(.top, 6)
                    }
                    if let objectiveProgress, let target = matchingObjective?.targetValue {
                        VStack(alignment: .leading, spacing: 4) {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(AppTheme.border.opacity(0.5)).frame(height: 6)
                                    Capsule().fill(AppTheme.accent).frame(width: geometry.size.width * objectiveProgress, height: 6)
                                }
                            }
                            .frame(height: 6)
                            Text("\(Int(objectiveProgress * 100))% du chemin vers \(target.formatted())\(type.unit)")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.top, 10)
                    }
                    if entries.count > 1 {
                        chart
                            .frame(height: 150)
                            .padding(.top, 6)
                    }
                }

                SectionLabel(text: "Historique")
                AppCard {
                    if entries.isEmpty {
                        Text("Aucune mesure enregistrée pour l'instant.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                if index > 0 { Divider().overlay(AppTheme.border) }
                                historyRow(entry)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle(type.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var chart: some View {
        let sorted = entries.sorted { $0.date < $1.date }
        return Chart(sorted) { entry in
            LineMark(
                x: .value("Date", entry.date),
                y: .value(type.rawValue, entry.value)
            )
            .foregroundStyle(AppTheme.accent)
            .interpolationMethod(.monotone)
            .symbol(Circle())
        }
        .chartXAxis {
            AxisMarks { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel(AppDateFormat.dayMonth.string(from: date))
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private func progressionPill(current: BodyMeasurementEntry, previous: BodyMeasurementEntry) -> some View {
        let delta = current.value - previous.value
        let colors = MeasurementProgressionStyle.colors(delta: delta, objective: matchingObjective)
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: previous.date),
            to: Calendar.current.startOfDay(for: current.date)
        ).day ?? 0
        return HStack(spacing: 4) {
            Image(systemName: delta < 0 ? "arrow.down.right" : delta > 0 ? "arrow.up.right" : "minus")
                .font(.system(size: 11, weight: .bold))
            Text("\(delta > 0 ? "+" : "")\(delta.formatted())\(type.unit)\(days > 0 ? " (\(days)j)" : "")")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(colors.text)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func historyRow(_ entry: BodyMeasurementEntry) -> some View {
        HStack {
            Text(AppDateFormat.dayFullMonth.string(from: entry.date))
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text(formattedValue(entry.value))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Button {
                context.delete(entry)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
    }
}
