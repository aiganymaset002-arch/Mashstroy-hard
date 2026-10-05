//
//  Vision.swift
//  MASHSTROY AI Control — Smart Conveyor
//
//  События компьютерного зрения с камеры установки.
//

import Foundation

public enum VisionEventKind: String, CaseIterable, Sendable {
    case beltMovement, beltMisalignment, materialPresent, noMaterial, hopperOverflow, jam
    case surfaceDamage, personInZone, smoke, leak, brickQuality

    public var title: String {
        switch self {
        case .beltMovement: return "Движение ленты"
        case .beltMisalignment: return "Смещение ленты"
        case .materialPresent: return "Материал на ленте"
        case .noMaterial: return "Нет материала"
        case .hopperOverflow: return "Переполнение бункера"
        case .jam: return "Застрявший материал"
        case .surfaceDamage: return "Повреждение поверхности"
        case .personInZone: return "Человек в опасной зоне"
        case .smoke: return "Дым"
        case .leak: return "Утечка"
        case .brickQuality: return "Качество мини-кирпича"
        }
    }
}

public struct VisionEvent: Identifiable, Hashable, Sendable {
    public var kind: VisionEventKind
    public var message: String
    public var risk: RiskLevel
    public var confidence: Double
    public var timestamp: Date

    public var id: VisionEventKind { kind }

    public init(kind: VisionEventKind, message: String, risk: RiskLevel, confidence: Double, timestamp: Date) {
        self.kind = kind
        self.message = message
        self.risk = risk
        self.confidence = confidence
        self.timestamp = timestamp
    }
}
