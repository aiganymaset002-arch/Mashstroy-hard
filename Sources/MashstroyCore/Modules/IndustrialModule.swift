//
//  IndustrialModule.swift
//  MASHSTROY AI Control
//
//  Реестр промышленных модулей. Каждый новый агрегат (очистка воды,
//  переработка шлама, лабораторные установки) добавляется сюда как ещё
//  один ModuleKind, со своей папкой в Core и своим экраном в UI.
//

import Foundation

public enum ModuleKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case smartConveyor
    case waterTreatment
    case sludgeRecycling
    case labUnits

    public var id: String { rawValue }
}

public enum ModuleAvailability: String, Codable, Sendable {
    case active
    case planned
}

public struct ModuleDescriptor: Identifiable, Hashable, Sendable {
    public let kind: ModuleKind
    public let title: String
    public let summary: String
    public let systemImage: String
    public let availability: ModuleAvailability

    public var id: ModuleKind { kind }

    public init(kind: ModuleKind, title: String, summary: String, systemImage: String, availability: ModuleAvailability) {
        self.kind = kind
        self.title = title
        self.summary = summary
        self.systemImage = systemImage
        self.availability = availability
    }
}

public enum ModuleRegistry {
    public static let all: [ModuleDescriptor] = [
        ModuleDescriptor(
            kind: .smartConveyor,
            title: "Smart Conveyor",
            summary: "Мониторинг конвейера: статус, скорость, загрузка, аварии и рекомендации ИИ",
            systemImage: "shippingbox.and.arrow.backward",
            availability: .active
        ),
        ModuleDescriptor(
            kind: .waterTreatment,
            title: "Очистка воды",
            summary: "Контроль качества воды, фильтров и реагентов",
            systemImage: "drop",
            availability: .planned
        ),
        ModuleDescriptor(
            kind: .sludgeRecycling,
            title: "Переработка шлама",
            summary: "Учёт шлама, режимы переработки и выход продукта",
            systemImage: "arrow.3.trianglepath",
            availability: .planned
        ),
        ModuleDescriptor(
            kind: .labUnits,
            title: "Лабораторные установки",
            summary: "Эксперименты, пробы и протоколы испытаний",
            systemImage: "flask",
            availability: .planned
        )
    ]

    public static func descriptor(for kind: ModuleKind) -> ModuleDescriptor {
        all.first { $0.kind == kind }!
    }
}
