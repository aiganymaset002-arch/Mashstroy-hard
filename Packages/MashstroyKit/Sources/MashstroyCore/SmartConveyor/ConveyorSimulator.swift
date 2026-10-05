//
//  ConveyorSimulator.swift
//  MASHSTROY AI Control — Smart Conveyor
//
//  Симулятор установки: все датчики, логика ESP32 (включая локальные
//  защиты) и ввод неисправностей для демонстрации ИИ-диагностики.
//  Детерминирован: одинаковый seed и шаг дают одинаковые данные.
//

import Foundation

public enum SimulatedFault: String, CaseIterable, Identifiable, Sendable {
    case bearingWear
    case motorOverload
    case airLeak
    case beltMisalignment
    case jam
    case fanFailure
    case personInZone
    case controllerOffline

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .bearingWear: return "Износ подшипника #2"
        case .motorOverload: return "Перегрузка двигателя"
        case .airLeak: return "Утечка воздушной камеры"
        case .beltMisalignment: return "Сход ленты"
        case .jam: return "Заклинивание материала"
        case .fanFailure: return "Отказ охлаждения двигателя"
        case .personInZone: return "Человек в опасной зоне"
        case .controllerOffline: return "Потеря связи с ESP32"
        }
    }

    /// Пока неисправность активна, сброс аварии не проходит.
    var blocksReset: Bool { self == .jam || self == .personInZone }
}

public final class ConveyorSimulator: ConveyorLink {
    public let machineID: String
    public private(set) var telemetry: ConveyorTelemetry
    public private(set) var activeFaults: Set<SimulatedFault> = []

    private let step: TimeInterval
    private let bootDate: Date
    private var rng: SeededGenerator
    private var tick = 0
    private var progress: [SimulatedFault: Double] = [:]
    private var pressPhase = 0

    /// Скорость развития введённой неисправности за шаг (0…1).
    public var faultGrowthPerStep = 0.03

    public init(machineID: String = "MS-CNV-0001", seed: UInt64 = 42, start: Date = Date(), step: TimeInterval = 1) {
        self.machineID = machineID
        self.step = step
        self.bootDate = start.addingTimeInterval(-3 * 3600)
        self.rng = SeededGenerator(seed: seed)
        self.telemetry = .idle(at: start)
    }

    // MARK: ConveyorLink

    public func poll() async throws -> ConveyorSnapshot {
        advance()
        return snapshot()
    }

    public func send(_ command: ConveyorCommand) async throws -> CommandResult {
        apply(command)
    }

    public func history(of metric: SensorMetric, range: HistoryRange) async throws -> [MetricPoint] {
        syntheticHistory(of: metric, range: range)
    }

    // MARK: Неисправности

    public func inject(_ fault: SimulatedFault) {
        activeFaults.insert(fault)
        progress[fault] = fault == .controllerOffline || fault == .personInZone ? 1 : 0
    }

    public func clear(_ fault: SimulatedFault) {
        activeFaults.remove(fault)
        progress[fault] = nil
    }

    public func clearAllFaults() {
        activeFaults.removeAll()
        progress.removeAll()
    }

    private func level(_ fault: SimulatedFault) -> Double {
        activeFaults.contains(fault) ? (progress[fault] ?? 0) : 0
    }

    // MARK: Команды

    @discardableResult
    public func apply(_ command: ConveyorCommand) -> CommandResult {
        var t = telemetry
        let verdict = ConveyorSafetyPolicy.validate(command, for: t)
        guard verdict.isAccepted else { return verdict }

        switch command {
        case .start:
            t.state = .running
            t.cycles += 1
        case .stop:
            if !t.state.isLatched { t.state = .stopped }
        case .pause:
            t.state = .paused
        case .emergencyStop:
            t.state = .emergency
            t.tripReason = "Аварийный стоп из приложения"
            t.beltSpeed = 0
        case .resetFault:
            if let blocking = activeFaults.first(where: { $0.blocksReset }) {
                return .rejected("Причина не устранена: \(blocking.title)")
            }
            t.state = .stopped
            t.tripReason = nil
        case .setSpeed(let v):
            t.speedSetpoint = v
        case .setControlMode(let m):
            t.controlMode = m
            if m == .automatic { t.speedSetpoint = t.mode.nominalSpeed }
        case .setDirection(let d):
            t.direction = d
        case .setFan(let i, let on):
            t.fans[i] = on
        case .setAirCushion(let on):
            t.airCushionOn = on
        case .setDrive(let on):
            t.driveEnabled = on
            if !on && t.state.isMoving { t.state = .stopped }
        case .setHopperFeed(let on):
            t.hopperFeedOn = on
        case .pressCycle:
            pressPhase = 1
            t.cycles += 1
        case .runMode(let m):
            t.mode = m
            t.controlMode = .automatic
            t.speedSetpoint = m.nominalSpeed
            t.airCushionOn = true
            t.hopperFeedOn = true
            if !t.state.isMoving { t.cycles += 1 }
            t.state = .running
        }
        telemetry = t
        return .accepted
    }

    // MARK: Физика

    /// Один шаг симуляции (1 опрос ESP32).
    public func advance() {
        tick += 1
        for fault in activeFaults {
            progress[fault] = min(1, (progress[fault] ?? 0) + faultGrowthPerStep)
        }

        var t = telemetry
        t.timestamp = t.timestamp.addingTimeInterval(step)

        if activeFaults.contains(.controllerOffline) {
            t.controllerOnline = false
            telemetry = t
            return
        }
        t.controllerOnline = true

        let bearing = level(.bearingWear)
        let overload = level(.motorOverload)
        let leak = level(.airLeak)
        let misalign = level(.beltMisalignment)
        let jam = level(.jam)
        let fanFail = level(.fanFailure)
        let moving = t.state.isMoving

        // Скорость и обороты
        let target = moving ? t.speedSetpoint * (1 - 0.6 * jam) * (1 - 0.08 * bearing) : 0
        t.beltSpeed = max(0, t.beltSpeed + (target - t.beltSpeed) * 0.35 + (moving ? rng.noise(0.01) : 0))
        t.motorRPM = t.beltSpeed * 955

        // Материал и бункер
        let feeding = moving && t.hopperFeedOn && t.hopperLevel > 1
        let loadTarget = feeding ? t.mode.nominalLoadKg * (1 + 0.8 * overload) : 0
        t.loadKg = max(0, t.loadKg + (loadTarget - t.loadKg) * 0.2 + (feeding ? rng.noise(0.6) : 0))
        let refill = t.hopperFeedOn ? 0.8 : 0
        let consumption = feeding ? 0.6 * t.beltSpeed : 0
        t.hopperLevel = min(100, max(0, t.hopperLevel + refill - consumption + (overload > 0.5 ? 0.5 : 0)))
        t.throughputKgPerHour = moving ? t.loadKg * t.beltSpeed * 10 : 0

        // Электрика
        if moving {
            t.current = 2.4 + 0.5 * t.beltSpeed / 1.2 + t.loadKg * 0.012
                + 0.7 * bearing + 2.4 * overload + 2.8 * jam + 0.4 * leak + rng.noise(0.05)
        } else {
            t.current = 0.4 + rng.noise(0.02)
        }
        t.voltage = 24 - t.current * 0.15 + rng.noise(0.05)

        // Воздушная подушка
        if t.airCushionOn {
            t.airPressure = NominalProfile.typicalAirPressure - 1.8 * leak + rng.noise(0.05 + 0.45 * leak)
        } else {
            t.airPressure = max(0, t.airPressure + (0.2 - t.airPressure) * 0.3)
        }

        // Температуры
        let fansOff = Double(t.fans.filter { !$0 }.count)
        let motorTarget = 25 + (moving ? t.current * 11 : 0) + fansOff * 5 + 30 * fanFail
        t.motorTemperature += (motorTarget - t.motorTemperature) * 0.06 + rng.noise(0.1)
        t.bearing1Temperature += ((25 + (moving ? 20 : 0)) - t.bearing1Temperature) * 0.05 + rng.noise(0.1)
        t.bearing2Temperature += ((25 + (moving ? 21 + 30 * bearing : 0)) - t.bearing2Temperature) * 0.05 + rng.noise(0.1)

        // Вибрация и сход ленты
        t.vibration = moving
            ? max(0.2, 1.8 + t.beltSpeed * 0.4 + 3.2 * bearing + 1.8 * jam + 0.9 * misalign + rng.noise(0.1))
            : 0.1 + abs(rng.noise(0.03))
        t.beltOffset = 2 * sin(Double(tick) / 15) + 17 * misalign + rng.noise(0.5)

        // Пресс
        if pressPhase > 0 {
            t.pressPosition = pressPhase <= 5 ? Double(pressPhase) * 20 : Double(10 - pressPhase) * 20
            pressPhase = pressPhase >= 10 ? 0 : pressPhase + 1
        } else {
            t.pressPosition = 0
        }

        if moving { t.uptime += step }

        // Локальные защиты ESP32
        if activeFaults.contains(.personInZone) && t.state != .emergency {
            trip(&t, state: .emergency, reason: "Человек в опасной зоне (камера)")
        } else if !t.state.isLatched {
            if t.current > NominalProfile.tripCurrent {
                trip(&t, state: .fault, reason: "Превышение тока двигателя")
            } else if t.motorTemperature > NominalProfile.tripMotorTemperature {
                trip(&t, state: .fault, reason: "Опасная температура двигателя")
            } else if t.vibration > NominalProfile.tripVibration {
                trip(&t, state: .fault, reason: "Превышение вибрации")
            } else if jam > 0.7 && moving {
                trip(&t, state: .fault, reason: "Заклинивание ленты")
            } else if moving {
                t.state = Self.hasWarning(t) ? .warning : .running
            }
        }

        telemetry = t
    }

    private func trip(_ t: inout ConveyorTelemetry, state: MachineState, reason: String) {
        t.state = state
        t.tripReason = reason
    }

    static func hasWarning(_ t: ConveyorTelemetry) -> Bool {
        SensorMetric.allCases.contains { $0.risk(in: t) > .low } || abs(t.beltOffset) > NominalProfile.maxBeltOffset
    }

    // MARK: Снимок

    public func snapshot() -> ConveyorSnapshot {
        let t = telemetry
        let controller = ControllerInfo(
            name: "ESP32 Main Controller",
            deviceID: "ESP32-3C71BF4A2E10",
            ipAddress: "192.168.1.47",
            firmware: "1.4.2",
            wifiSSID: "MASHSTROY-LAB",
            rssi: t.controllerOnline ? -55 - (tick % 7) : -100,
            uptime: t.timestamp.timeIntervalSince(bootDate),
            online: t.controllerOnline
        )
        return ConveyorSnapshot(machineID: machineID, telemetry: t, controller: controller,
                                modules: modules(for: t), visionEvents: visionEvents(for: t))
    }

    private func modules(for t: ConveyorTelemetry) -> [HardwareModuleState] {
        HardwareModuleState.derive(from: t, coolingFault: level(.fanFailure) > 0.3)
    }

    private func visionEvents(for t: ConveyorTelemetry) -> [VisionEvent] {
        guard t.controllerOnline else { return [] }
        var events: [VisionEvent] = []
        func add(_ kind: VisionEventKind, _ message: String, _ risk: RiskLevel, _ confidence: Double) {
            events.append(VisionEvent(kind: kind, message: message, risk: risk, confidence: confidence, timestamp: t.timestamp))
        }

        if activeFaults.contains(.personInZone) {
            add(.personInZone, "Человек в опасной зоне у приводного барабана", .critical, 0.96)
        }
        if level(.jam) > 0.3 {
            add(.jam, "Материал застрял у выхода бункера", .high, 0.84)
        }
        if level(.fanFailure) > 0.8 {
            add(.smoke, "Возможный дым в зоне двигателя", .high, 0.61)
        }
        if abs(t.beltOffset) > NominalProfile.maxBeltOffset {
            add(.beltMisalignment, "Belt misalignment detected: \(Int(abs(t.beltOffset))) mm", abs(t.beltOffset) > 15 ? .high : .medium, 0.91)
        }
        if t.hopperLevel > 95 {
            add(.hopperOverflow, "Бункер заполнен на \(Int(t.hopperLevel))%", .medium, 0.88)
        }
        if t.state.isMoving {
            add(.beltMovement, "Лента движется, \(String(format: "%.2f", t.beltSpeed)) м/с", .low, 0.97)
            if t.loadKg > 1 {
                add(.materialPresent, "Материал на ленте, заполнение \(Int(t.loadPercent))%", .low, 0.95)
            } else {
                add(.noMaterial, "Лента пустая", .low, 0.9)
            }
            if t.mode == .ecoBrick {
                let quality = max(60, 94 - 20 * level(.airLeak) - 15 * level(.beltMisalignment))
                add(.brickQuality, "Качество мини-кирпича: \(Int(quality))%", quality < 85 ? .medium : .low, 0.82)
            }
        }
        return events.sorted { $0.risk > $1.risk }
    }

    // MARK: История

    /// Синтетическая история за период. В реальной версии её отдаёт облако.
    func syntheticHistory(of metric: SensorMetric, range: HistoryRange) -> [MetricPoint] {
        guard range != .live else { return [] }
        let stableHash = metric.rawValue.unicodeScalars.reduce(UInt64(17)) { $0 &* 31 &+ UInt64($1.value) }
        var gen = SeededGenerator(seed: stableHash &* UInt64(range.pointCount))
        let count = range.pointCount
        let interval = range.duration / Double(count)
        let end = telemetry.timestamp
        let base = metric.typicalValue
        return (0..<count).map { i in
            let date = end.addingTimeInterval(-Double(count - 1 - i) * interval)
            let hourOfDay = Double(Calendar.current.component(.hour, from: date))
            let shiftFactor = (hourOfDay >= 8 && hourOfDay < 20) ? 1.0 : 0.85
            let wear: Double
            switch metric {
            case .vibration, .bearing2Temperature: wear = 1 + 0.25 * Double(i) / Double(count)
            default: wear = 1
            }
            let value = base * shiftFactor * wear * (1 + gen.noise(0.05))
            return MetricPoint(date: date, value: value)
        }
    }
}
