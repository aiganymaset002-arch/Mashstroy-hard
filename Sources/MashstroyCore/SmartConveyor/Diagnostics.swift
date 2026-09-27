//
//  Diagnostics.swift
//  MASHSTROY AI Control — Smart Conveyor
//
//  AI Sensor Monitor и Predictive Maintenance.
//  Первая версия — объяснимые правила по отклонениям от номинала и
//  трендам. Каждый диагноз отвечает на вопросы: что произошло →
//  возможная причина → вероятность → что проверить → насколько срочно.
//  Протокол DiagnosticsAnalyzing позволяет позже подключить ML-модель,
//  обученную на закрытых карточках Fault Center.
//

import Foundation

public enum MachineComponent: String, CaseIterable, Identifiable, Codable, Sendable {
    case motor, bearing1, bearing2, belt, airChamber, pressActuator, controller

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .motor: return "Двигатель"
        case .bearing1: return "Подшипник #1"
        case .bearing2: return "Подшипник #2"
        case .belt: return "Лента"
        case .airChamber: return "Воздушная камера"
        case .pressActuator: return "Актуатор пресса"
        case .controller: return "Контроллер ESP32"
        }
    }
}

public enum DiagnosisKind: String, CaseIterable, Codable, Sendable {
    case controllerOffline, protectionTrip, bearingDegradation, airChamberLeak
    case motorOverload, beltJam, motorOverheating, beltMisalignment, beltOverload
    /// Карточка из облака с видом, неизвестным этой версии приложения.
    case other
}

public struct Diagnosis: Identifiable, Hashable, Sendable {
    public var kind: DiagnosisKind
    public var component: MachineComponent
    /// Что произошло.
    public var title: String
    /// Наблюдения: «Вибрация ↑ 34%».
    public var evidence: [String]
    /// Возможная причина.
    public var cause: String
    /// Вероятность 0…1.
    public var probability: Double
    /// Что проверить.
    public var checks: [String]
    /// Насколько срочно.
    public var risk: RiskLevel
    public var action: String
    public var measured: String
    public var normal: String

    public var id: DiagnosisKind { kind }
}

public struct ComponentHealth: Identifiable, Hashable, Sendable {
    public var component: MachineComponent
    /// 0…100.
    public var health: Int
    /// Оставшийся ресурс, моточасы (nil — деградации не видно).
    public var remainingHours: Double?
    public var uncertaintyHours: Double?

    public var id: MachineComponent { component }

    public var note: String {
        if health < 60 { return "Требуется осмотр" }
        if health < 80 { return "Осмотр в плановое ТО" }
        return "Норма"
    }
}

public struct DiagnosticsReport: Hashable, Sendable {
    public var diagnoses: [Diagnosis]
    public var components: [ComponentHealth]
    public var overallHealth: Int

    public static let empty = DiagnosticsReport(diagnoses: [], components: [], overallHealth: 100)

    /// Узел, который раньше всех потребует обслуживания.
    public var nextMaintenance: ComponentHealth? {
        components.filter { $0.remainingHours != nil }.min { ($0.remainingHours ?? 0) < ($1.remainingHours ?? 0) }
    }
}

public protocol DiagnosticsAnalyzing: Sendable {
    func analyze(_ history: [ConveyorTelemetry]) -> DiagnosticsReport
}

public struct DiagnosticsEngine: DiagnosticsAnalyzing {
    /// Размер окна усреднения (замеров).
    public var window = 10
    /// Здоровье, при котором узел считается выработавшим ресурс.
    public var endOfLifeHealth = 40.0

    public init() {}

    public func analyze(_ history: [ConveyorTelemetry]) -> DiagnosticsReport {
        guard let last = history.last else { return .empty }
        var result: [Diagnosis] = []

        if !last.controllerOnline {
            result.append(Diagnosis(
                kind: .controllerOffline, component: .controller,
                title: "Нет связи с ESP32 Main Controller",
                evidence: ["Последние данные: \(Self.timeFormatter.string(from: last.timestamp))"],
                cause: "Потеря Wi-Fi, питание контроллера или зависание прошивки",
                probability: 0.99,
                checks: ["Питание ESP32", "Уровень сигнала Wi-Fi", "Перезагрузить контроллер"],
                risk: .high,
                action: "Проверить установку на месте. Локальные защиты ESP32 продолжают работать без связи",
                measured: "Нет данных", normal: "Онлайн"))
        }

        if last.state.isLatched, let reason = last.tripReason {
            result.append(Diagnosis(
                kind: .protectionTrip, component: component(forTrip: reason),
                title: last.state == .emergency ? "Аварийный стоп: \(reason)" : "Локальная защита остановила конвейер: \(reason)",
                evidence: ["Состояние: \(last.state.rawValue)"],
                cause: reason,
                probability: 1,
                checks: ["Осмотреть установку до сброса", "Убедиться, что в опасной зоне нет людей", "Устранить причину и нажать Reset Fault"],
                risk: .critical,
                action: "Не перезапускать до устранения причины",
                measured: last.state.rawValue, normal: "RUNNING / STOPPED"))
        }

        let moving = history.filter { $0.state.isMoving && $0.controllerOnline }
        let recent = Array(moving.suffix(window))
        if recent.count >= 3 {
            result += mechanicalDiagnoses(recent)
        }

        result.sort { ($0.risk, $0.probability) > ($1.risk, $1.probability) }
        let components = componentHealth(history: moving, last: last)
        let healthValues = components.map { Double($0.health) }
        let average = healthValues.reduce(0, +) / Double(max(1, healthValues.count))
        let overall = Int(min(average, (healthValues.min() ?? 100) + 20))
        return DiagnosticsReport(diagnoses: result, components: components, overallHealth: overall)
    }

    // MARK: Правила

    private func mechanicalDiagnoses(_ r: [ConveyorTelemetry]) -> [Diagnosis] {
        var out: [Diagnosis] = []
        let vib = Self.mean(r.map(\.vibration))
        let cur = Self.mean(r.map(\.current))
        let speed = Self.mean(r.map(\.beltSpeed))
        let setpoint = Self.mean(r.map(\.speedSetpoint))
        let b1 = Self.mean(r.map(\.bearing1Temperature))
        let b2 = Self.mean(r.map(\.bearing2Temperature))
        let motorTemp = r.last?.motorTemperature ?? 0
        let offset = Self.mean(r.map(\.beltOffset))
        let load = Self.mean(r.map(\.loadKg))

        let vibChange = vib / NominalProfile.typicalVibration - 1
        let curChange = cur / NominalProfile.typicalCurrent - 1
        let speedDrop = setpoint > 0 ? 1 - speed / setpoint : 0

        var trend: [String] = []
        if vibChange > 0.05 { trend.append("Вибрация ↑ \(Self.percent(vibChange))") }
        if curChange > 0.05 { trend.append("Ток двигателя ↑ \(Self.percent(curChange))") }
        if speedDrop > 0.05 { trend.append("Скорость ленты ↓ \(Self.percent(speedDrop))") }

        let isJam = curChange > 0.4 && speedDrop > 0.15
        if isJam {
            out.append(Diagnosis(
                kind: .beltJam, component: .belt,
                title: "Заклинивание ленты или материала",
                evidence: trend,
                cause: "Застрявший материал, посторонний предмет или заедание барабана",
                probability: min(0.95, 0.55 + speedDrop + curChange * 0.2),
                checks: ["Выход бункера и зона загрузки", "Натяжение ленты", "Приводной и натяжной барабаны"],
                risk: speedDrop > 0.3 ? .critical : .high,
                action: "Остановить установку и освободить ленту",
                measured: "Ток: \(Self.f(cur, 1)) A, скорость: \(Self.f(speed, 2)) м/с",
                normal: "Ток: 2.8–3.6 A, скорость: \(Self.f(setpoint, 2)) м/с"))
        }

        if vibChange > 0.25 {
            let bearing: MachineComponent = b2 > b1 + 5 ? .bearing2 : .bearing1
            var evidence = trend
            let hotBearing = max(b1, b2)
            if hotBearing > 50 { evidence.append("\(bearing.title): \(Int(hotBearing)) °C") }
            let probability = min(0.95, 0.45 + vibChange * 0.5 + max(0, curChange) * 0.6 + (hotBearing > NominalProfile.maxBearingTemperature ? 0.1 : 0) - (isJam ? 0.2 : 0))
            let high = vib > 5 || hotBearing > NominalProfile.maxBearingTemperature
            out.append(Diagnosis(
                kind: .bearingDegradation, component: bearing,
                title: "Possible bearing degradation",
                evidence: evidence,
                cause: "Износ \(bearing == .bearing2 ? "подшипника #2" : "подшипника #1"), перекос вала или повышенное сопротивление ленты",
                probability: probability,
                checks: ["Люфт и шум \(bearing.title.lowercased())", "Смазка подшипника", "Соосность вала и барабана"],
                risk: high ? .high : .medium,
                action: high ? "Остановить установку в ближайшее окно и заменить подшипник" : "Inspection recommended within 14 operating hours",
                measured: "Вибрация: \(Self.f(vib, 2)) мм/с",
                normal: "до \(Self.f(NominalProfile.maxVibration, 1)) мм/с"))
        }

        if r.last?.airCushionOn == true {
            let pressures = r.map(\.airPressure)
            let pressure = Self.mean(pressures)
            let std = Self.standardDeviation(pressures)
            let drop = 1 - pressure / NominalProfile.typicalAirPressure
            if pressure < NominalProfile.airPressureRange.lowerBound || std > 0.2 {
                var evidence: [String] = []
                if drop > 0.03 { evidence.append("Давление ↓ \(Self.percent(drop))") }
                if std > 0.2 { evidence.append("Колебания давления ±\(Self.f(std, 2)) кПа") }
                out.append(Diagnosis(
                    kind: .airChamberLeak, component: .airChamber,
                    title: std > 0.2 ? "Pressure instability detected" : "Падение давления воздушной подушки",
                    evidence: evidence,
                    cause: "Possible air chamber leakage: утечка камеры или износ уплотнения",
                    probability: min(0.95, 0.5 + max(0, drop) * 1.2 + min(std / 0.2, 2) * 0.1),
                    checks: ["Уплотнения воздушной камеры", "Шланги и соединения", "Работа вентиляторов подушки"],
                    risk: pressure < 3.5 ? .high : .medium,
                    action: "Проверить камеру на утечку в ближайшую остановку",
                    measured: "Давление: \(Self.f(pressure, 2)) кПа",
                    normal: "4.5–6.0 кПа"))
            }
        }

        if !isJam && cur > NominalProfile.currentRange.upperBound * 1.25 {
            out.append(Diagnosis(
                kind: .motorOverload, component: .motor,
                title: "Перегрузка двигателя",
                evidence: trend + ["Нагрузка: \(Int(load)) кг"],
                cause: "Перегруз материалом, повышенное сопротивление ленты или проблема привода",
                probability: min(0.95, 0.6 + (cur / NominalProfile.currentRange.upperBound - 1.25)),
                checks: ["Подачу материала", "Натяжение ленты", "Драйвер BTS7960 и проводку двигателя"],
                risk: .high,
                action: "Снизить подачу материала, при росте тока остановить установку и проверить привод",
                measured: "Ток: \(Self.f(cur, 1)) A",
                normal: "2.8–3.6 A"))
        }

        if motorTemp > NominalProfile.maxMotorTemperature {
            let fansOff = r.last?.fans.enumerated().filter { !$0.element }.map { "Вентилятор \($0.offset + 1) выключен" } ?? []
            out.append(Diagnosis(
                kind: .motorOverheating, component: .motor,
                title: "Перегрев двигателя",
                evidence: ["Температура двигателя: \(Int(motorTemp)) °C"] + fansOff,
                cause: "Недостаточное охлаждение, загрязнение или длительная перегрузка",
                probability: min(0.95, 0.6 + (motorTemp - NominalProfile.maxMotorTemperature) / 30),
                checks: ["Вентиляторы охлаждения", "Загрязнение корпуса двигателя", "Ток двигателя"],
                risk: motorTemp > 85 ? .high : .medium,
                action: "Снизить нагрузку и проверить охлаждение",
                measured: "\(Int(motorTemp)) °C",
                normal: "до \(Int(NominalProfile.maxMotorTemperature)) °C"))
        }

        if abs(offset) > NominalProfile.maxBeltOffset {
            out.append(Diagnosis(
                kind: .beltMisalignment, component: .belt,
                title: "Сход ленты: \(Int(abs(offset))) мм",
                evidence: ["Смещение к \(offset > 0 ? "правому" : "левому") краю"],
                cause: "Перекос натяжного барабана или неравномерная загрузка",
                probability: min(0.95, 0.6 + (abs(offset) - NominalProfile.maxBeltOffset) / 20),
                checks: ["Центровку натяжного барабана", "Равномерность загрузки", "Состояние кромки ленты"],
                risk: abs(offset) > 15 ? .high : .medium,
                action: "Отрегулировать натяжной барабан со стороны \(offset > 0 ? "правого" : "левого") края",
                measured: "\(Int(abs(offset))) мм",
                normal: "до \(Int(NominalProfile.maxBeltOffset)) мм"))
        }

        if load > NominalProfile.maxLoadKg {
            out.append(Diagnosis(
                kind: .beltOverload, component: .belt,
                title: "Перегруз ленты",
                evidence: ["Нагрузка: \(Int(load)) кг (\(Int(load / NominalProfile.maxLoadKg * 100))%)"],
                cause: "Слишком высокая подача из бункера",
                probability: 0.9,
                checks: ["Заслонку бункера", "Режим подачи"],
                risk: .medium,
                action: "Уменьшить подачу материала",
                measured: "\(Int(load)) кг",
                normal: "до \(Int(NominalProfile.maxLoadKg)) кг"))
        }

        return out
    }

    // MARK: Здоровье узлов и RUL

    func healthScores(_ r: [ConveyorTelemetry]) -> [MachineComponent: Double] {
        guard !r.isEmpty else { return [:] }
        let vibChange = max(0, Self.mean(r.map(\.vibration)) / NominalProfile.typicalVibration - 1)
        let curChange = max(0, Self.mean(r.map(\.current)) / NominalProfile.typicalCurrent - 1)
        let motorTemp = Self.mean(r.map(\.motorTemperature))
        let b1 = Self.mean(r.map(\.bearing1Temperature))
        let b2 = Self.mean(r.map(\.bearing2Temperature))
        let offset = abs(Self.mean(r.map(\.beltOffset)))
        let pressures = r.map(\.airPressure)
        let pressureDrop = max(0, 1 - Self.mean(pressures) / NominalProfile.typicalAirPressure)
        let instability = Self.standardDeviation(pressures) / 0.2
        let cycles = Double(r.last?.cycles ?? 0)
        let b2Share = b2 > b1 + 5 ? 0.8 : 0.5

        func clamp(_ v: Double) -> Double { min(100, max(0, v)) }
        return [
            .motor: clamp(100 - curChange * 80 - max(0, motorTemp - 60) * 1.2),
            .bearing1: clamp(100 - vibChange * 80 * (1 - b2Share) - max(0, b1 - 50) * 1.5),
            .bearing2: clamp(100 - vibChange * 80 * b2Share - max(0, b2 - 50) * 1.5),
            .belt: clamp(100 - max(0, offset - 3) * 3),
            .airChamber: clamp(100 - pressureDrop * 150 - max(0, instability - 1) * 10),
            .pressActuator: clamp(100 - cycles / 50)
        ]
    }

    private func componentHealth(history moving: [ConveyorTelemetry], last: ConveyorTelemetry) -> [ComponentHealth] {
        let recent = Array(moving.suffix(window))
        let previous = Array(moving.dropLast(recent.count).suffix(window))
        let now = healthScores(recent)
        let before = healthScores(previous)

        // Моточасы между центрами окон.
        var hoursBetween: Double?
        if let r0 = recent.first?.timestamp, let r1 = recent.last?.timestamp,
           let p0 = previous.first?.timestamp, let p1 = previous.last?.timestamp {
            let recentCenter = r0.timeIntervalSince1970 + r1.timeIntervalSince(r0) / 2
            let previousCenter = p0.timeIntervalSince1970 + p1.timeIntervalSince(p0) / 2
            hoursBetween = max(1, recentCenter - previousCenter) / 3600
        }

        var list: [ComponentHealth] = MachineComponent.allCases.compactMap { (component) -> ComponentHealth? in
            guard component != .controller else { return nil }
            let health = now[component] ?? 100
            var rul: Double?
            var uncertainty: Double?
            if let old = before[component], let hours = hoursBetween {
                let ratePerHour = (old - health) / hours
                // Деградация должна превышать шум датчиков.
                if old - health > 2, health < 95 {
                    rul = max(0, (health - endOfLifeHealth) / max(ratePerHour, 0.001))
                    uncertainty = max(0.1, (rul ?? 0) * 0.2)
                }
            }
            return ComponentHealth(component: component, health: Int(health.rounded()),
                                   remainingHours: rul, uncertaintyHours: uncertainty)
        }
        list.append(ComponentHealth(component: .controller, health: last.controllerOnline ? 100 : 0,
                                    remainingHours: nil, uncertaintyHours: nil))
        return list
    }

    // MARK: Помощники

    private func component(forTrip reason: String) -> MachineComponent {
        let r = reason.lowercased()
        if r.contains("ток") || r.contains("температур") { return .motor }
        if r.contains("вибрац") { return .bearing2 }
        if r.contains("заклин") { return .belt }
        return .controller
    }

    static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let m = mean(values)
        return (values.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(values.count - 1)).squareRoot()
    }

    static func percent(_ fraction: Double) -> String { "\(Int((fraction * 100).rounded()))%" }

    static func f(_ value: Double, _ digits: Int) -> String { String(format: "%.\(digits)f", value) }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return f
    }()
}
