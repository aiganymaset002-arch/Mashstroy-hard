//
//  MashstroyTheme.swift
//  MASHSTROY AI Control
//

#if canImport(SwiftUI)
import SwiftUI
import MashstroyCore

enum MashstroyTheme {
    static let primary = Color(red: 0.05, green: 0.18, blue: 0.32)
    static let accent = Color(red: 0.96, green: 0.62, blue: 0.07)
    static let ok = Color(red: 0.10, green: 0.60, blue: 0.30)
    static let warning = Color(red: 0.90, green: 0.55, blue: 0.0)
    static let critical = Color(red: 0.80, green: 0.12, blue: 0.12)

    static func color(for severity: AlertSeverity) -> Color {
        switch severity {
        case .info: return primary
        case .warning: return warning
        case .critical: return critical
        }
    }

    static func color(for status: ConveyorStatus) -> Color {
        switch status {
        case .running: return ok
        case .idle: return warning
        case .stopped: return .gray
        case .fault: return critical
        }
    }

    static func color(forHealth score: Int) -> Color {
        score >= 80 ? ok : (score >= 50 ? warning : critical)
    }
}
#endif
