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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppCard {
                    StatTile(
                        label: type.rawValue,
                        value: entries.first.map { formattedValue($0.value) } ?? "—",
                        target: matchingObjective?.targetValue.map { "\($0.formatted())\(type.unit)" }
                    )
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
