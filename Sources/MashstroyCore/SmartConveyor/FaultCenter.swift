//
//  FaultCenter.swift
//  MASHSTROY AI Control — Smart Conveyor
//
//  Центр поломок: каждая неисправность получает номер FAULT-ГГГГ-NNNNN
//  и проходит путь Новая → Принята → В ремонте → Устранена. Запись
//  техника о реальной причине потом становится датасетом для ИИ.
//

import Foundation

public enum FaultStatus: String, CaseIterable, Codable, Sendable {
    case new, accepted, repairing, resolved

    public var title: String {
        switch self {
        case .new: return "Новая"
        case .accepted: return "Accepted"
        case .repairing: return "Repairing"
        case .resolved: return "Resolved"
        }
    }

    public var next: FaultStatus? {
        switch self {
        case .new: return .accepted
        case .accepted: return .repairing
        case .repairing: return .resolved
        case .resolved: return nil
        }
    }

    public var actionTitle: String? {
        switch next {
        case .accepted: return "Принять"
        case .repairing: return "Начать ремонт"
        case .resolved: return "Устранено"
        default: return nil
        }
    }
}

public struct FaultStatusChange: Hashable, Codable, Sendable {
    public var status: FaultStatus
    public var date: Date
    public var note: String
}

public struct FaultRecord: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: DiagnosisKind
    public let component: MachineComponent
    public let detectedAt: Date
    public let title: String
    public let measured: String
    public let normal: String
    public let evidence: [String]
    public let aiDiagnosis: String
    public let probability: Double
    public let risk: RiskLevel
    public let action: String
    public internal(set) var status: FaultStatus
    public internal(set) var technicianNote: String
    public internal(set) var log: [FaultStatusChange]

    public var isOpen: Bool { status != .resolved }
}

public enum FaultCenterError: LocalizedError, Equatable {
    case notFound
    case alreadyResolved
    case noteRequired

    public var errorDescription: String? {
        switch self {
        case .notFound: return "Карточка не найдена"
        case .alreadyResolved: return "Неисправность уже устранена"
        case .noteRequired: return "Опишите, что реально было неисправно"
        }
    }
}

public struct FaultCenter: Hashable, Sendable {
    /// Новые сверху.
    public private(set) var records: [FaultRecord]
    private var lastNumberByYear: [Int: Int]

    public init(records: [FaultRecord] = [], lastNumber: Int = 40, year: Int = Calendar.current.component(.year, from: Date())) {
        self.records = records
        self.lastNumberByYear = [year: lastNumber]
    }

    public var openCount: Int { records.filter(\.isOpen).count }

    public static func makeID(year: Int, number: Int) -> String {
        "FAULT-\(year)-\(String(format: "%05d", number))"
    }

    /// Заводит карточки по диагнозам со срочностью от средней и выше.
    /// Повторно не заводит, пока по тому же диагнозу есть открытая карточка.
    @discardableResult
    public mutating func register(_ diagnoses: [Diagnosis], at date: Date) -> [FaultRecord] {
        var created: [FaultRecord] = []
        for d in diagnoses where d.risk >= .medium {
            if records.contains(where: { $0.isOpen && $0.kind == d.kind }) { continue }
            let year = Calendar.current.component(.year, from: date)
            let number = (lastNumberByYear[year] ?? 0) + 1
            lastNumberByYear[year] = number
            let record = FaultRecord(
                id: Self.makeID(year: year, number: number),
                kind: d.kind, component: d.component, detectedAt: date, title: d.title,
                measured: d.measured, normal: d.normal, evidence: d.evidence,
                aiDiagnosis: d.cause, probability: d.probability, risk: d.risk, action: d.action,
                status: .new, technicianNote: "",
                log: [FaultStatusChange(status: .new, date: date, note: "Обнаружено ИИ")])
            records.insert(record, at: 0)
            created.append(record)
        }
        return created
    }

    /// Переводит карточку на следующий шаг. Для «Устранено» нужна запись техника.
    @discardableResult
    public mutating func advance(id: String, note: String, at date: Date) throws -> FaultRecord {
        guard let index = records.firstIndex(where: { $0.id == id }) else { throw FaultCenterError.notFound }
        guard let next = records[index].status.next else { throw FaultCenterError.alreadyResolved }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if next == .resolved && trimmed.isEmpty { throw FaultCenterError.noteRequired }

        records[index].status = next
        if !trimmed.isEmpty { records[index].technicianNote = trimmed }
        records[index].log.append(FaultStatusChange(status: next, date: date, note: trimmed))
        return records[index]
    }
}
