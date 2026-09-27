//
//  History.swift
//  MASHSTROY AI Control — Smart Conveyor
//

import Foundation

public enum HistoryRange: String, CaseIterable, Identifiable, Sendable {
    case live, hour, day, week, month

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .live: return "Live"
        case .hour: return "1 ч"
        case .day: return "24 ч"
        case .week: return "7 дн"
        case .month: return "30 дн"
        }
    }

    public var duration: TimeInterval {
        switch self {
        case .live: return 120
        case .hour: return 3_600
        case .day: return 86_400
        case .week: return 7 * 86_400
        case .month: return 30 * 86_400
        }
    }

    public var pointCount: Int {
        switch self {
        case .live: return 120
        case .hour: return 60
        case .day: return 96
        case .week: return 168
        case .month: return 120
        }
    }
}

public struct MetricPoint: Identifiable, Hashable, Sendable {
    public var date: Date
    public var value: Double

    public var id: Date { date }

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct MetricSummary: Hashable, Sendable {
    public let min: Double
    public let max: Double
    public let average: Double

    public init?(_ points: [MetricPoint]) {
        guard let lo = points.map(\.value).min(), let hi = points.map(\.value).max() else { return nil }
        min = lo
        max = hi
        average = points.map(\.value).reduce(0, +) / Double(points.count)
    }
}
