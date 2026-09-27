//
//  DashboardView.swift
//  MASHSTROY AI Control — Главный Dashboard
//

#if canImport(SwiftUI)
import SwiftUI
import MashstroyCore

struct DashboardView: View {
    @EnvironmentObject private var store: ConveyorStore

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            if let snap = store.snapshot {
                VStack(alignment: .leading, spacing: 16) {
                    header(snap)
                    if let reason = snap.telemetry.tripReason, snap.telemetry.state.isLatched {
                        Label(reason, systemImage: "exclamationmark.octagon.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(MashstroyTheme.critical, in: RoundedRectangle(cornerRadius: 14))
                    }
                    metrics(snap.telemetry)
                    warnings
                    maintenance
                    camera(snap)
                }
                .padding()
            } else {
                ProgressView("Подключение к ESP32…").frame(maxWidth: .infinity, minHeight: 300)
            }
        }
        .background(Color.secondary.opacity(0.06))
        .navigationTitle("Smart Conveyor")
    }

    private func header(_ snap: ConveyorSnapshot) -> some View {
        let t = snap.telemetry
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(snap.machineID).font(.caption.monospaced()).foregroundStyle(.secondary)
                StateBadge(state: t.state)
                HStack(spacing: 6) {
                    Circle().fill(t.controllerOnline ? MashstroyTheme.ok : Color.gray).frame(width: 8, height: 8)
                    Text(t.controllerOnline ? "ESP32 онлайн" : "ESP32 офлайн").font(.caption)
                }
                Text("\(t.mode.title) · \(t.controlMode.title)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(store.report.overallHealth)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(MashstroyTheme.color(forHealth: store.report.overallHealth))
                Text("здоровье, %").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func metrics(_ t: ConveyorTelemetry) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(SensorMetric.allCases) { metric in
                MetricTile(title: metric.title, value: metric.format(metric.value(in: t)), unit: metric.unit,
                           systemImage: metric.systemImage, risk: metric.risk(in: t))
            }
            MetricTile(title: "Загрузка ленты", value: "\(Int(t.loadPercent))", unit: "%", systemImage: "percent",
                       risk: SensorMetric.load.risk(in: t))
            MetricTile(title: "Время работы", value: Formatters.duration(t.uptime), unit: "", systemImage: "clock")
            MetricTile(title: "Циклы", value: "\(t.cycles)", unit: "", systemImage: "repeat")
            MetricTile(title: "Направление", value: t.direction.title, unit: "", systemImage: "arrow.left.arrow.right")
        }
    }

    private var warnings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Активные предупреждения").font(.headline)
            if store.report.diagnoses.isEmpty {
                Label("Нет активных предупреждений", systemImage: "checkmark.circle").foregroundStyle(MashstroyTheme.ok)
            } else {
                ForEach(store.report.diagnoses.prefix(4)) { d in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.title).font(.subheadline.bold())
                            Text(d.evidence.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        RiskBadge(risk: d.risk)
                    }
                }
            }
        }
        .card()
    }

    private var maintenance: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Прогноз ТО", systemImage: "wrench.and.screwdriver").font(.headline)
            if let next = store.report.nextMaintenance, let hours = next.remainingHours {
                Text("\(next.component.title): осталось \(Formatters.hours(hours)) ± \(Formatters.hours(next.uncertaintyHours ?? 0)) моточасов")
                Text("Здоровье узла: \(next.health)%").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Деградации не обнаружено. Следующее ТО по графику.")
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func camera(_ snap: ConveyorSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Камера").font(.headline)
            CameraFeedView(telemetry: snap.telemetry, events: snap.visionEvents)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if let top = snap.visionEvents.first {
                HStack {
                    Text(top.message).font(.caption)
                    Spacer()
                    RiskBadge(risk: top.risk)
                }
            }
        }
        .card()
    }
}
#endif
