//
//  DiagnosticsView.swift
//  MASHSTROY AI Control — AI Sensor Monitor и Predictive Maintenance
//

#if canImport(SwiftUI)
import SwiftUI
import MashstroyCore

struct DiagnosticsView: View {
    @EnvironmentObject private var store: ConveyorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Диагнозы ИИ").font(.title3.bold())
                if store.report.diagnoses.isEmpty {
                    Label("Аномалий не обнаружено", systemImage: "checkmark.seal")
                        .foregroundStyle(MashstroyTheme.ok)
                        .card()
                } else {
                    ForEach(store.report.diagnoses) { DiagnosisCard(diagnosis: $0) }
                }

                Text("Predictive Maintenance").font(.title3.bold()).padding(.top, 8)
                VStack(spacing: 14) {
                    ForEach(store.report.components) { ComponentHealthRow(item: $0) }
                }
                .card()

                Text("Правила ИИ анализируют отклонения от номинала и тренды за последние замеры. Закрытые карточки аварий с записью техника станут обучающими данными для ML-модели.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Color.secondary.opacity(0.06))
        .navigationTitle("AI Sensor Monitor")
    }
}

struct DiagnosisCard: View {
    let diagnosis: Diagnosis

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(diagnosis.title).font(.headline)
                    Text(diagnosis.component.title).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                RiskBadge(risk: diagnosis.risk)
            }
            if !diagnosis.evidence.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(diagnosis.evidence, id: \.self) { Text($0).font(.subheadline.monospacedDigit()) }
                }
            }
            row("Что произошло", diagnosis.title)
            row("Возможная причина", diagnosis.cause)
            row("Вероятность", "Confidence: \(Formatters.percent(diagnosis.probability))")
            VStack(alignment: .leading, spacing: 2) {
                Text("Что проверить").font(.caption).foregroundStyle(.secondary)
                ForEach(diagnosis.checks, id: \.self) { Text("• \($0)").font(.subheadline) }
            }
            row("Насколько срочно", "\(diagnosis.risk.title). \(diagnosis.action)")
        }
        .card()
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline)
        }
    }
}

struct ComponentHealthRow: View {
    let item: ComponentHealth

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.component.title).font(.subheadline.bold())
                Spacer()
                Text("Health: \(item.health)%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(MashstroyTheme.color(forHealth: item.health))
            }
            HealthBar(health: item.health)
            HStack {
                Text(item.note)
                Spacer()
                if let rul = item.remainingHours {
                    Text("RUL: \(Formatters.hours(rul)) ± \(Formatters.hours(item.uncertaintyHours ?? 0)) моточ.")
                        .monospacedDigit()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
#endif
