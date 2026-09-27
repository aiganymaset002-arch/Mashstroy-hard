//
//  SmartConveyorDashboardView.swift
//  MASHSTROY AI Control — Smart Conveyor
//
//  Дашборд: статус, скорость, загрузка, температура, вибрация,
//  тренд загрузки, аварии и рекомендации ИИ.
//

#if canImport(SwiftUI)
import SwiftUI
import Charts
import MashstroyCore

public struct SmartConveyorDashboardView: View {
    @StateObject private var model: SmartConveyorViewModel

    public init(model: @autoclosure @escaping () -> SmartConveyorViewModel = SmartConveyorViewModel()) {
        _model = StateObject(wrappedValue: model())
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let reading = model.current, let analysis = model.analysis {
                    StatusHeader(reading: reading, healthScore: analysis.healthScore)
                    metricsGrid(reading)
                    LoadTrendCard(history: model.history, limit: model.limits.maxLoadPercent)
                    AlertsCard(alerts: analysis.alerts)
                    RecommendationsCard(recommendations: analysis.recommendations)
                } else {
                    ProgressView("Подключение к конвейеру…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding()
        }
        .background(Color.secondary.opacity(0.06))
        .navigationTitle("Smart Conveyor")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(model.isLive ? "Пауза" : "Старт") {
                    model.isLive ? model.stop() : model.start()
                }
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private func metricsGrid(_ r: ConveyorReading) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(title: "Скорость", value: String(format: "%.2f", r.speed), unit: "м/с",
                       fraction: r.speed / model.limits.maxSpeed, systemImage: "speedometer")
            MetricTile(title: "Загрузка", value: "\(Int(r.loadPercent))", unit: "%",
                       fraction: r.loadPercent / model.limits.maxLoadPercent, systemImage: "scalemass")
            MetricTile(title: "Двигатель", value: "\(Int(r.motorTemperature))", unit: "°C",
                       fraction: r.motorTemperature / model.limits.maxMotorTemperature, systemImage: "thermometer.medium")
            MetricTile(title: "Вибрация", value: String(format: "%.1f", r.vibration), unit: "мм/с",
                       fraction: r.vibration / model.limits.maxVibration, systemImage: "waveform.path")
        }
    }
}

private struct StatusHeader: View {
    let reading: ConveyorReading
    let healthScore: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Статус").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Circle().fill(MashstroyTheme.color(for: reading.status)).frame(width: 12, height: 12)
                    Text(reading.status.title).font(.title2.bold())
                }
                Text(reading.timestamp, style: .time).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(healthScore)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(MashstroyTheme.color(forHealth: healthScore))
                Text("индекс здоровья").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let unit: String
    let fraction: Double
    let systemImage: String

    private var tint: Color {
        fraction > 1 ? MashstroyTheme.critical : (fraction > 0.85 ? MashstroyTheme.warning : MashstroyTheme.ok)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.title.bold()).monospacedDigit()
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(fraction, 0), 1)).tint(tint)
        }
        .card()
    }
}

private struct LoadTrendCard: View {
    let history: [ConveyorReading]
    let limit: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Загрузка, последние \(history.count) с").font(.headline)
            Chart {
                ForEach(Array(history.enumerated()), id: \.offset) { index, reading in
                    LineMark(x: .value("t", index), y: .value("Загрузка", reading.loadPercent))
                        .foregroundStyle(MashstroyTheme.primary)
                }
                RuleMark(y: .value("Предел", limit))
                    .foregroundStyle(MashstroyTheme.critical)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartXAxis(.hidden)
            .chartYScale(domain: 0...max(120, limit * 1.2))
            .frame(height: 140)
        }
        .card()
    }
}

private struct AlertsCard: View {
    let alerts: [ConveyorAlert]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Аварии и предупреждения").font(.headline)
            if alerts.isEmpty {
                Label("Нет активных предупреждений", systemImage: "checkmark.circle")
                    .foregroundStyle(MashstroyTheme.ok)
            } else {
                ForEach(alerts) { alert in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: alert.severity == .critical ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(MashstroyTheme.color(for: alert.severity))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.message)
                            Text(alert.severity.title).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct RecommendationsCard: View {
    let recommendations: [AIRecommendation]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Рекомендации ИИ", systemImage: "sparkles").font(.headline)
            ForEach(recommendations) { rec in
                VStack(alignment: .leading, spacing: 4) {
                    Text(rec.title).font(.subheadline.bold())
                        .foregroundStyle(MashstroyTheme.color(for: rec.priority))
                    Text(rec.detail).font(.subheadline)
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private extension View {
    func card() -> some View {
        padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

#Preview {
    NavigationStack { SmartConveyorDashboardView() }
}
#endif
