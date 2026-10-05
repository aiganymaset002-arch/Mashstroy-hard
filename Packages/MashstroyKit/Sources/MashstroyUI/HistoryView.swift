//
//  HistoryView.swift
//  MASHSTROY AI Control — Графики и история
//

#if canImport(SwiftUI)
import SwiftUI
import Charts
#if canImport(MashstroyCore)
import MashstroyCore
#endif

struct HistoryView: View {
    @EnvironmentObject private var store: ConveyorStore
    @State private var metric: SensorMetric = .vibration
    @State private var range: HistoryRange = .live
    @State private var points: [MetricPoint] = []

    var body: some View {
        List {
            Section {
                Picker("Датчик", selection: $metric) {
                    ForEach(SensorMetric.allCases) { Text($0.title).tag($0) }
                }
                Picker("Период", selection: $range) {
                    ForEach(HistoryRange.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("\(metric.title), \(metric.unit)") {
                if points.isEmpty {
                    Text("Нет данных").foregroundStyle(.secondary)
                } else {
                    chart.frame(height: 220)
                }
            }
            if let summary = MetricSummary(points) {
                Section("Статистика") {
                    LabeledContent("Минимум", value: "\(metric.format(summary.min)) \(metric.unit)")
                    LabeledContent("Максимум", value: "\(metric.format(summary.max)) \(metric.unit)")
                    LabeledContent("Среднее", value: "\(metric.format(summary.average)) \(metric.unit)")
                    if let normal = metric.normalRange {
                        LabeledContent("Норма", value: "\(metric.format(normal.lowerBound))–\(metric.format(normal.upperBound)) \(metric.unit)")
                    }
                }
            }
            Section {
                Text(range == .live
                     ? "Live: последние \(HistoryRange.live.pointCount) замеров с конвейера."
                     : "История за период — синтетические данные симулятора. С ESP32 её будет отдавать MASHSTROY Cloud.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Графики")
        .task(id: reloadKey) {
            points = await store.history(of: metric, range: range)
        }
    }

    /// Live перезагружается на каждом замере, остальные периоды — при смене датчика или периода.
    private var reloadKey: String {
        let tick = range == .live ? (store.telemetry?.timestamp.timeIntervalSince1970 ?? 0) : 0
        return "\(metric.rawValue)-\(range.rawValue)-\(tick)"
    }

    private var chart: some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Время", point.date), y: .value(metric.title, point.value))
                    .foregroundStyle(MashstroyTheme.primary)
            }
            if let normal = metric.normalRange {
                RuleMark(y: .value("Верхняя граница", normal.upperBound))
                    .foregroundStyle(MashstroyTheme.critical)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
    }
}
#endif
