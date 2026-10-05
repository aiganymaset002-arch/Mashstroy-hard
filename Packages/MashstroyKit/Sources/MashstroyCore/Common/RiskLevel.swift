//
//  RiskLevel.swift
//  MASHSTROY AI Control
//

import Foundation

/// Общая шкала срочности для аварий, диагнозов ИИ и событий камеры.
public enum RiskLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .low: return "Низкий"
        case .medium: return "Средний"
        case .high: return "Высокий"
        case .critical: return "Критический"
        }
    }
}
