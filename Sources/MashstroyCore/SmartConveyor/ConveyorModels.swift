//
//  ConveyorModels.swift
//  MASHSTROY AI Control — Smart Conveyor
//

import Foundation

public enum ConveyorStatus: String, Codable, Sendable {
    case running
    case idle
    case stopped
    case fault

    public var title: String {
        switch self {
        case .running: return "В работе"
        case .idle: return "Холостой ход"
        case .stopped: return "Остановлен"
        case .fault: return "Авария"
        }
    }
}

/// Паспортные пределы конвейера. Значения по умолчанию — для демо-линии.
public struct ConveyorLimits: Codable, Hashable, Sendable {
    public var maxSpeed: Double          // м/с
    public var maxLoadPercent: Double    // %
    public var maxMotorTemperature: Double // °C
    public var maxVibration: Double      // мм/с (RMS)

    public init(maxSpeed: Double = 2.5, maxLoadPercent: Double = 100, maxMotorTemperature: Double = 85, maxVibration: Double = 7.1) {
        self.maxSpeed = maxSpeed
        self.maxLoadPercent = maxLoadPercent
        self.maxMotorTemperature = maxMotorTemperature
        self.maxVibration = maxVibration
    }

    public static let standard = ConveyorLimits()
}

/// Снимок телеметрии конвейера в один момент времени.
public struct ConveyorReading: Codable, Hashable, Sendable {
    public var timestamp: Date
    public var status: ConveyorStatus
    public var speed: Double              // м/с
    public var loadPercent: Double        // % от номинальной загрузки
    public var motorTemperature: Double   // °C
    public var vibration: Double          // мм/с
    public var beltAlignmentOffset: Double // мм, сход ленты от оси

    public init(timestamp: Date = Date(), status: ConveyorStatus, speed: Double, loadPercent: Double,
                motorTemperature: Double, vibration: Double, beltAlignmentOffset: Double) {
        self.timestamp = timestamp
        self.status = status
        self.speed = speed
        self.loadPercent = loadPercent
        self.motorTemperature = motorTemperature
        self.vibration = vibration
        self.beltAlignmentOffset = beltAlignmentOffset
    }
}

public enum AlertSeverity: Int, Codable, Comparable, Sendable {
    case info = 0
    case warning = 1
    case critical = 2

    public static func < (lhs: AlertSeverity, rhs: AlertSeverity) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .info: return "Инфо"
        case .warning: return "Внимание"
        case .critical: return "Критично"
        }
    }
}

public struct ConveyorAlert: Identifiable, Hashable, Sendable {
    public let id: String
    public let severity: AlertSeverity
    public let message: String

    public init(id: String, severity: AlertSeverity, message: String) {
        self.id = id
        self.severity = severity
        self.message = message
    }
}

public struct AIRecommendation: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let priority: AlertSeverity

    public init(id: String, title: String, detail: String, priority: AlertSeverity) {
        self.id = id
        self.title = title
        self.detail = detail
        self.priority = priority
    }
}

/// Результат анализа: аварии, рекомендации и общий индекс здоровья 0…100.
public struct ConveyorAnalysis: Hashable, Sendable {
    public let alerts: [ConveyorAlert]
    public let recommendations: [AIRecommendation]
    public let healthScore: Int
}
