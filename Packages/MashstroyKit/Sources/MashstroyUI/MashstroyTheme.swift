//
//  MashstroyTheme.swift
//  MASHSTROY AI Control
//

#if canImport(SwiftUI)
import SwiftUI
#if canImport(MashstroyCore)
import MashstroyCore
#endif

enum MashstroyTheme {
    // Цвета логотипа Asset МАШСТРОЙ: тёмно-зелёный и фирменный зелёный.
    static let primary = Color(red: 0.09, green: 0.33, blue: 0.04)
    static let accent = Color(red: 0.36, green: 0.76, blue: 0.0)
    static let ok = Color(red: 0.10, green: 0.60, blue: 0.30)
    static let warning = Color(red: 0.90, green: 0.55, blue: 0.0)
    static let critical = Color(red: 0.80, green: 0.12, blue: 0.12)

    static func color(for risk: RiskLevel) -> Color {
        switch risk {
        case .low: return ok
        case .medium: return warning
        case .high, .critical: return critical
        }
    }

    static func color(for state: MachineState) -> Color {
        switch state {
        case .running: return ok
        case .paused: return accent
        case .stopped: return .gray
        case .warning: return warning
        case .fault, .emergency: return critical
        }
    }

    static func color(for status: LinkStatus) -> Color {
        switch status {
        case .online: return ok
        case .warning: return warning
        case .offline: return .gray
        }
    }

    static func color(for status: FaultStatus) -> Color {
        switch status {
        case .new: return critical
        case .accepted: return warning
        case .repairing: return accent
        case .resolved: return ok
        }
    }

    static func color(forHealth score: Int) -> Color {
        score >= 80 ? ok : (score >= 60 ? warning : critical)
    }
}

/// Логотип Asset МАШСТРОЙ (App/…/Assets.xcassets/BrandLogo) на его чёрном фоне.
struct BrandLogo: View {
    var maxHeight: CGFloat = 96

    var body: some View {
        Image("BrandLogo")
            .resizable()
            .scaledToFit()
            .frame(maxHeight: maxHeight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityLabel("Asset МАШСТРОЙ")
    }
}

#endif
