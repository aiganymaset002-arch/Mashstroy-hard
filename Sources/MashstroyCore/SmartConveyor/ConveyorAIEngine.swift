//
//  ConveyorAIEngine.swift
//  MASHSTROY AI Control — Smart Conveyor
//
//  Первая версия «ИИ» — прозрачные правила по телеметрии и её тренду.
//  Интерфейс ConveyorAnalyzing позволяет позже подменить движок на
//  ML-модель или облачный сервис без изменений в UI.
//

import Foundation

public protocol ConveyorAnalyzing: Sendable {
    func analyze(current: ConveyorReading, history: [ConveyorReading], limits: ConveyorLimits) -> ConveyorAnalysis
}

public struct ConveyorAIEngine: ConveyorAnalyzing {
    public init() {}

    public func analyze(current r: ConveyorReading, history: [ConveyorReading], limits: ConveyorLimits) -> ConveyorAnalysis {
        var alerts: [ConveyorAlert] = []
        var recs: [AIRecommendation] = []
        var health = 100.0

        if r.status == .fault {
            alerts.append(.init(id: "fault", severity: .critical, message: "Конвейер в аварийном состоянии"))
            recs.append(.init(id: "fault-inspect", title: "Проверить линию",
                              detail: "Заблокируйте привод (LOTO) и осмотрите ленту, ролики и датчики перед перезапуском.",
                              priority: .critical))
            health -= 40
        }

        // Загрузка
        let loadRatio = r.loadPercent / limits.maxLoadPercent
        if loadRatio > 1.0 {
            alerts.append(.init(id: "overload", severity: .critical,
                                message: "Перегрузка: \(Int(r.loadPercent))% от номинала"))
            recs.append(.init(id: "overload-feed", title: "Снизить подачу материала",
                              detail: "Уменьшите подачу на входе на \(Int((loadRatio - 1) * 100) + 5)%, чтобы вернуть загрузку в норму.",
                              priority: .critical))
            health -= 25
        } else if loadRatio > 0.9 {
            alerts.append(.init(id: "high-load", severity: .warning,
                                message: "Высокая загрузка: \(Int(r.loadPercent))%"))
            health -= 10
        } else if r.status == .running && loadRatio < 0.3 {
            recs.append(.init(id: "underload-speed", title: "Снизить скорость ленты",
                              detail: "Загрузка \(Int(r.loadPercent))%. Снижение скорости до \(format(r.speed * 0.7)) м/с сэкономит энергию и уменьшит износ.",
                              priority: .info))
        }

        // Скорость
        if r.speed > limits.maxSpeed {
            alerts.append(.init(id: "overspeed", severity: .critical,
                                message: "Скорость \(format(r.speed)) м/с выше предела \(format(limits.maxSpeed)) м/с"))
            health -= 20
        }

        // Температура двигателя
        let tempRatio = r.motorTemperature / limits.maxMotorTemperature
        if tempRatio >= 1.0 {
            alerts.append(.init(id: "motor-hot", severity: .critical,
                                message: "Перегрев двигателя: \(Int(r.motorTemperature)) °C"))
            health -= 25
        } else if tempRatio > 0.85 {
            alerts.append(.init(id: "motor-warm", severity: .warning,
                                message: "Двигатель нагрет: \(Int(r.motorTemperature)) °C"))
            health -= 10
        }
        if let rise = temperatureRisePerReading(history: history + [r]), rise > 0.5, tempRatio > 0.7 {
            recs.append(.init(id: "motor-trend", title: "Проверить охлаждение двигателя",
                              detail: "Температура растёт на \(format(rise)) °C за замер. Проверьте вентилятор и смазку подшипников.",
                              priority: .warning))
        }

        // Вибрация
        if r.vibration > limits.maxVibration {
            alerts.append(.init(id: "vibration", severity: .critical,
                                message: "Вибрация \(format(r.vibration)) мм/с выше нормы"))
            recs.append(.init(id: "vibration-bearings", title: "Осмотреть подшипники и ролики",
                              detail: "Высокая вибрация обычно означает износ подшипников или дисбаланс барабана. Запланируйте осмотр в ближайшую остановку.",
                              priority: .warning))
            health -= 20
        } else if r.vibration > limits.maxVibration * 0.7 {
            alerts.append(.init(id: "vibration-rising", severity: .warning,
                                message: "Вибрация растёт: \(format(r.vibration)) мм/с"))
            health -= 5
        }

        // Сход ленты
        if abs(r.beltAlignmentOffset) > 15 {
            alerts.append(.init(id: "misalignment", severity: .warning,
                                message: "Сход ленты \(Int(abs(r.beltAlignmentOffset))) мм"))
            recs.append(.init(id: "alignment", title: "Отрегулировать центровку ленты",
                              detail: "Подтяните натяжной барабан со стороны \(r.beltAlignmentOffset > 0 ? "правого" : "левого") края.",
                              priority: .warning))
            health -= 10
        }

        if alerts.isEmpty && recs.isEmpty {
            recs.append(.init(id: "all-good", title: "Работа в норме",
                              detail: "Параметры в допустимых пределах. Следующее ТО — по графику.",
                              priority: .info))
        }

        alerts.sort { $0.severity > $1.severity }
        recs.sort { $0.priority > $1.priority }
        return ConveyorAnalysis(alerts: alerts, recommendations: recs,
                                healthScore: Int(max(0, min(100, health))))
    }

    /// Средний прирост температуры за замер по последним 5 значениям.
    func temperatureRisePerReading(history: [ConveyorReading]) -> Double? {
        let recent = history.suffix(5).map(\.motorTemperature)
        guard recent.count >= 3, let first = recent.first, let last = recent.last else { return nil }
        return (last - first) / Double(recent.count - 1)
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
