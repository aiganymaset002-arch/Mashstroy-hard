//
//  Telemetry.swift
//  MASHSTROY AI Control — Smart Conveyor
//
//  Телеметрия конвейера в том виде, в каком её будет отдавать ESP32.
//

import Foundation

public enum MachineState: String, Codable, CaseIterable, Sendable {
    case running = "RUNNING"
    case paused = "PAUSED"
    case stopped = "STOPPED"
    case warning = "WARNING"
    case fault = "FAULT"
    case emergency = "EMERGENCY"

    public var title: String {
        switch self {
        case .running: return "Работает"
        case .paused: return "Пауза"
        case .stopped: return "Остановлен"
        case .warning: return "Предупреждение"
        case .fault: return "Авария"
        case .emergency: return "Аварийный стоп"
        }
    }

    /// Лента движется.
    public var isMoving: Bool { self == .running || self == .warning }

    /// Установка заблокирована до сброса аварии.
    public var isLatched: Bool { self == .fault || self == .emergency }
}

public enum OperatingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case ecoBrick
    case sludgeProcessing
    case materialTransport
    case research

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ecoBrick: return "Mode 1 — Eco Brick"
        case .sludgeProcessing: return "Mode 2 — Sludge Processing"
        case .materialTransport: return "Mode 3 — Material Transport"
        case .research: return "Mode 4 — Testing / Research"
        }
    }

    public var summary: String {
        switch self {
        case .ecoBrick: return "Подача смеси и прессование мини-кирпича"
        case .sludgeProcessing: return "Медленная подача шлама, повышенная нагрузка"
        case .materialTransport: return "Транспортировка материала на номинальной скорости"
        case .research: return "Испытания: малая нагрузка, ручная настройка"
        }
    }

    /// Скорость ленты, м/с, которую режим задаёт в автоматическом управлении.
    public var nominalSpeed: Double {
        switch self {
        case .ecoBrick: return 0.8
        case .sludgeProcessing: return 0.6
        case .materialTransport: return 1.2
        case .research: return 0.5
        }
    }

    /// Масса материала на ленте, кг.
    public var nominalLoadKg: Double {
        switch self {
        case .ecoBrick: return 32
        case .sludgeProcessing: return 40
        case .materialTransport: return 30
        case .research: return 12
        }
    }
}

public enum ControlMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case manual
    case automatic

    public var id: String { rawValue }
    public var title: String { self == .manual ? "Ручной" : "Автоматический" }
}

public enum BeltDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case forward
    case reverse

    public var id: String { rawValue }
    public var title: String { self == .forward ? "Вперёд" : "Реверс" }
}

/// Снимок телеметрии конвейера.
public struct ConveyorTelemetry: Codable, Hashable, Sendable {
    public var timestamp: Date
    public var state: MachineState
    public var tripReason: String?
    public var controllerOnline: Bool

    public var beltSpeed: Double          // м/с
    public var speedSetpoint: Double      // м/с
    public var motorRPM: Double           // об/мин
    public var current: Double            // А
    public var voltage: Double            // В
    public var loadKg: Double             // кг на ленте
    public var airPressure: Double        // кПа в воздушной камере
    public var motorTemperature: Double   // °C
    public var bearing1Temperature: Double // °C
    public var bearing2Temperature: Double // °C
    public var vibration: Double          // мм/с RMS
    public var beltOffset: Double         // мм, сход ленты (+ вправо)
    public var hopperLevel: Double        // % заполнения бункера
    public var pressPosition: Double      // % хода пресса
    public var throughputKgPerHour: Double
    public var uptime: TimeInterval       // время работы ленты, с
    public var cycles: Int

    public var mode: OperatingMode
    public var controlMode: ControlMode
    public var direction: BeltDirection
    public var fans: [Bool]
    public var airCushionOn: Bool
    public var driveEnabled: Bool
    public var hopperFeedOn: Bool

    public var power: Double { current * voltage }
    public var loadPercent: Double { loadKg / NominalProfile.maxLoadKg * 100 }

    public init(timestamp: Date, state: MachineState, tripReason: String? = nil, controllerOnline: Bool = true,
                beltSpeed: Double, speedSetpoint: Double, motorRPM: Double, current: Double, voltage: Double,
                loadKg: Double, airPressure: Double, motorTemperature: Double, bearing1Temperature: Double,
                bearing2Temperature: Double, vibration: Double, beltOffset: Double, hopperLevel: Double,
                pressPosition: Double, throughputKgPerHour: Double, uptime: TimeInterval, cycles: Int,
                mode: OperatingMode, controlMode: ControlMode, direction: BeltDirection, fans: [Bool],
                airCushionOn: Bool, driveEnabled: Bool, hopperFeedOn: Bool) {
        self.timestamp = timestamp
        self.state = state
        self.tripReason = tripReason
        self.controllerOnline = controllerOnline
        self.beltSpeed = beltSpeed
        self.speedSetpoint = speedSetpoint
        self.motorRPM = motorRPM
        self.current = current
        self.voltage = voltage
        self.loadKg = loadKg
        self.airPressure = airPressure
        self.motorTemperature = motorTemperature
        self.bearing1Temperature = bearing1Temperature
        self.bearing2Temperature = bearing2Temperature
        self.vibration = vibration
        self.beltOffset = beltOffset
        self.hopperLevel = hopperLevel
        self.pressPosition = pressPosition
        self.throughputKgPerHour = throughputKgPerHour
        self.uptime = uptime
        self.cycles = cycles
        self.mode = mode
        self.controlMode = controlMode
        self.direction = direction
        self.fans = fans
        self.airCushionOn = airCushionOn
        self.driveEnabled = driveEnabled
        self.hopperFeedOn = hopperFeedOn
    }

    /// Остановленный конвейер в исходном состоянии.
    public static func idle(at date: Date = Date()) -> ConveyorTelemetry {
        ConveyorTelemetry(timestamp: date, state: .stopped, beltSpeed: 0, speedSetpoint: OperatingMode.materialTransport.nominalSpeed,
                          motorRPM: 0, current: 0.4, voltage: 24, loadKg: 0, airPressure: 5.2,
                          motorTemperature: 25, bearing1Temperature: 25, bearing2Temperature: 25, vibration: 0.1,
                          beltOffset: 0, hopperLevel: 60, pressPosition: 0, throughputKgPerHour: 0, uptime: 0, cycles: 0,
                          mode: .materialTransport, controlMode: .manual, direction: .forward, fans: [true, true, true],
                          airCushionOn: true, driveEnabled: true, hopperFeedOn: true)
    }
}

/// Номинальные значения и допустимые диапазоны для демо-линии Smart Conveyor.
public enum NominalProfile {
    public static let maxLoadKg = 50.0
    public static let speedRange: ClosedRange<Double> = 0.2...2.0
    public static let currentRange: ClosedRange<Double> = 2.8...3.6
    public static let typicalCurrent = 3.2
    public static let voltageRange: ClosedRange<Double> = 23.0...25.0
    public static let airPressureRange: ClosedRange<Double> = 4.5...6.0
    public static let typicalAirPressure = 5.2
    public static let maxMotorTemperature = 75.0
    public static let maxBearingTemperature = 65.0
    public static let maxVibration = 3.5
    public static let typicalVibration = 2.3
    public static let maxBeltOffset = 10.0
    /// Пределы локальных защит ESP32: при превышении контроллер сам останавливает установку.
    public static let tripCurrent = 6.0
    public static let tripMotorTemperature = 90.0
    public static let tripVibration = 7.1
}

/// Датчик/показатель, который можно вывести плиткой или графиком.
public enum SensorMetric: String, CaseIterable, Identifiable, Sendable {
    case beltSpeed, motorRPM, current, voltage, power, load, airPressure
    case motorTemperature, bearing1Temperature, bearing2Temperature, vibration, throughput

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .beltSpeed: return "Скорость ленты"
        case .motorRPM: return "Обороты двигателя"
        case .current: return "Ток"
        case .voltage: return "Напряжение"
        case .power: return "Мощность"
        case .load: return "Нагрузка на ленту"
        case .airPressure: return "Давление воздуха"
        case .motorTemperature: return "Темп. двигателя"
        case .bearing1Temperature: return "Подшипник #1"
        case .bearing2Temperature: return "Подшипник #2"
        case .vibration: return "Вибрация"
        case .throughput: return "Производительность"
        }
    }

    public var unit: String {
        switch self {
        case .beltSpeed: return "м/с"
        case .motorRPM: return "об/мин"
        case .current: return "А"
        case .voltage: return "В"
        case .power: return "Вт"
        case .load: return "кг"
        case .airPressure: return "кПа"
        case .motorTemperature, .bearing1Temperature, .bearing2Temperature: return "°C"
        case .vibration: return "мм/с"
        case .throughput: return "кг/ч"
        }
    }

    public var systemImage: String {
        switch self {
        case .beltSpeed: return "speedometer"
        case .motorRPM: return "gearshape.2"
        case .current: return "bolt"
        case .voltage: return "bolt.horizontal"
        case .power: return "powerplug"
        case .load: return "scalemass"
        case .airPressure: return "wind"
        case .motorTemperature: return "thermometer.medium"
        case .bearing1Temperature, .bearing2Temperature: return "circle.circle"
        case .vibration: return "waveform.path"
        case .throughput: return "shippingbox"
        }
    }

    public var fractionDigits: Int {
        switch self {
        case .beltSpeed, .current, .airPressure, .vibration: return 2
        case .voltage: return 1
        default: return 0
        }
    }

    /// Нормальный диапазон для работающей линии (nil — без ограничения).
    public var normalRange: ClosedRange<Double>? {
        switch self {
        case .beltSpeed: return NominalProfile.speedRange
        case .current: return NominalProfile.currentRange
        case .voltage: return NominalProfile.voltageRange
        case .load: return 0...NominalProfile.maxLoadKg
        case .airPressure: return NominalProfile.airPressureRange
        case .motorTemperature: return 0...NominalProfile.maxMotorTemperature
        case .bearing1Temperature, .bearing2Temperature: return 0...NominalProfile.maxBearingTemperature
        case .vibration: return 0...NominalProfile.maxVibration
        case .motorRPM, .power, .throughput: return nil
        }
    }

    public func value(in t: ConveyorTelemetry) -> Double {
        switch self {
        case .beltSpeed: return t.beltSpeed
        case .motorRPM: return t.motorRPM
        case .current: return t.current
        case .voltage: return t.voltage
        case .power: return t.power
        case .load: return t.loadKg
        case .airPressure: return t.airPressure
        case .motorTemperature: return t.motorTemperature
        case .bearing1Temperature: return t.bearing1Temperature
        case .bearing2Temperature: return t.bearing2Temperature
        case .vibration: return t.vibration
        case .throughput: return t.throughputKgPerHour
        }
    }

    /// Оценка показателя: в норме, у границы или вне нормы.
    /// Нижние границы тока и скорости проверяются только на движущейся ленте.
    public func risk(in t: ConveyorTelemetry) -> RiskLevel {
        guard let range = normalRange else { return .low }
        let v = value(in: t)
        let checksLowerBound = t.state.isMoving || self == .voltage || (self == .airPressure && t.airCushionOn)
        if v > range.upperBound * 1.2 || (checksLowerBound && v < range.lowerBound * 0.8) { return .high }
        if v > range.upperBound || (checksLowerBound && v < range.lowerBound) { return .medium }
        return .low
    }

    public func format(_ value: Double) -> String {
        String(format: "%.\(fractionDigits)f", value)
    }

    /// Типичное значение и разброс — для синтетической истории симулятора.
    var typicalValue: Double {
        switch self {
        case .beltSpeed: return 1.1
        case .motorRPM: return 1050
        case .current: return 3.2
        case .voltage: return 23.5
        case .power: return 75
        case .load: return 28
        case .airPressure: return 5.2
        case .motorTemperature: return 58
        case .bearing1Temperature: return 44
        case .bearing2Temperature: return 46
        case .vibration: return 2.3
        case .throughput: return 320
        }
    }
}
