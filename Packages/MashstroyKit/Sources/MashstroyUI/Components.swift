//
//  Components.swift
//  MASHSTROY AI Control
//

#if canImport(SwiftUI)
import SwiftUI
#if canImport(MashstroyCore)
import MashstroyCore
#endif

extension View {
    func card() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }
}

struct StateBadge: View {
    let state: MachineState

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(MashstroyTheme.color(for: state)).frame(width: 10, height: 10)
            Text(state.rawValue).font(.headline.monospaced())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(MashstroyTheme.color(for: state).opacity(0.15), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Состояние: \(state.title)")
    }
}

struct RiskBadge: View {
    let risk: RiskLevel
    var body: some View {
        Badge(text: risk.title, color: MashstroyTheme.color(for: risk))
            .accessibilityLabel("Риск: \(risk.title)")
    }
}

struct StatusDot: View {
    let status: LinkStatus
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(MashstroyTheme.color(for: status)).frame(width: 8, height: 8)
            Text(status.title).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    var risk: RiskLevel = .low

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.title2.bold()).monospacedDigit()
                    .foregroundStyle(risk > .low ? MashstroyTheme.color(for: risk) : .primary)
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
        }
        .card()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(risk > .low ? "\(value) \(unit), вне нормы" : "\(value) \(unit)")
    }
}

struct HealthBar: View {
    let health: Int

    var body: some View {
        ProgressView(value: Double(health), total: 100)
            .tint(MashstroyTheme.color(forHealth: health))
            .accessibilityLabel("Здоровье узла")
            .accessibilityValue("\(health) процентов")
    }
}

enum Formatters {
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d ч %02d мин", h, m) : String(format: "%d мин %02d с", m, s)
    }

    static func hours(_ value: Double) -> String {
        value >= 10 ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    static func percent(_ fraction: Double) -> String { "\(Int((fraction * 100).rounded()))%" }

    static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm"
        return f
    }()
}
#endif
