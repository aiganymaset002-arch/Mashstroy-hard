//
//  Hardware.swift
//  MASHSTROY AI Control — Smart Conveyor
//
//  Электроника установки: главный контроллер ESP32 и его модули.
//

import Foundation

public enum LinkStatus: String, Codable, Sendable {
    case online
    case warning
    case offline

    public var title: String {
        switch self {
        case .online: return "В сети"
        case .warning: return "Внимание"
        case .offline: return "Нет связи"
        }
    }
}

public struct ControllerInfo: Hashable, Sendable {
    public var name: String
    public var deviceID: String
    public var ipAddress: String
    public var firmware: String
    public var wifiSSID: String
    public var rssi: Int
    public var uptime: TimeInterval
    public var online: Bool

    public init(name: String, deviceID: String, ipAddress: String, firmware: String, wifiSSID: String,
                rssi: Int, uptime: TimeInterval, online: Bool) {
        self.name = name
        self.deviceID = deviceID
        self.ipAddress = ipAddress
        self.firmware = firmware
        self.wifiSSID = wifiSSID
        self.rssi = rssi
        self.uptime = uptime
        self.online = online
    }

    public var signalQuality: String {
        switch rssi {
        case (-60)...: return "Отличный"
        case (-70)...: return "Хороший"
        case (-80)...: return "Слабый"
        default: return "Очень слабый"
        }
    }
}

public enum HardwareModuleKind: String, CaseIterable, Identifiable, Sendable {
    case motorController, bts7960, powerMonitor, loadCell, imu, encoder
    case pressureSensor, temperatureSensors, limitSwitches, camera, fans, pressActuator

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .motorController: return "Motor Controller"
        case .bts7960: return "BTS7960"
        case .powerMonitor: return "INA219/INA226"
        case .loadCell: return "HX711 + Load Cell"
        case .imu: return "MPU6050"
        case .encoder: return "Hall/Encoder"
        case .pressureSensor: return "Pressure Sensor"
        case .temperatureSensors: return "Temperature Sensors"
        case .limitSwitches: return "Limit Switches"
        case .camera: return "Camera"
        case .fans: return "Fans"
        case .pressActuator: return "Linear Actuator / Press"
        }
    }

    public var role: String {
        switch self {
        case .motorController: return "Логика привода ленты"
        case .bts7960: return "Силовой драйвер двигателя (ШИМ)"
        case .powerMonitor: return "Ток, напряжение, мощность"
        case .loadCell: return "Масса материала на ленте"
        case .imu: return "Вибрация и наклон"
        case .encoder: return "Обороты и скорость ленты"
        case .pressureSensor: return "Давление в воздушной камере"
        case .temperatureSensors: return "Двигатель и подшипники"
        case .limitSwitches: return "Защитная крышка и концевики пресса"
        case .camera: return "Видеопоток для компьютерного зрения"
        case .fans: return "Охлаждение и воздушная подушка"
        case .pressActuator: return "Прессование мини-кирпича"
        }
    }

    public var systemImage: String {
        switch self {
        case .motorController: return "cpu"
        case .bts7960: return "bolt.circle"
        case .powerMonitor: return "bolt"
        case .loadCell: return "scalemass"
        case .imu: return "waveform.path"
        case .encoder: return "gauge.with.dots.needle.33percent"
        case .pressureSensor: return "wind"
        case .temperatureSensors: return "thermometer.medium"
        case .limitSwitches: return "switch.2"
        case .camera: return "video"
        case .fans: return "fan"
        case .pressActuator: return "arrow.down.to.line"
        }
    }
}

public struct HardwareModuleState: Identifiable, Hashable, Sendable {
    public var kind: HardwareModuleKind
    public var status: LinkStatus
    public var readings: [String]

    public var id: HardwareModuleKind { kind }

    public init(kind: HardwareModuleKind, status: LinkStatus, readings: [String]) {
        self.kind = kind
        self.status = status
        self.readings = readings
    }
}

extension HardwareModuleState {
    /// Состояние модулей по телеметрии: так их показывает и симулятор, и облачная версия.
    public static func derive(from t: ConveyorTelemetry, coolingFault: Bool = false) -> [HardwareModuleState] {
        func f(_ v: Double, _ digits: Int = 1) -> String { String(format: "%.\(digits)f", v) }
        func status(_ warn: Bool) -> LinkStatus { t.controllerOnline ? (warn ? .warning : .online) : .offline }
        let risk = { (m: SensorMetric) in m.risk(in: t) > .low }

        return HardwareModuleKind.allCases.map { (kind) -> HardwareModuleState in
            switch kind {
            case .motorController:
                return HardwareModuleState(kind: kind, status: status(t.state.isLatched),
                             readings: ["Состояние: \(t.state.rawValue)", "Задание: \(f(t.speedSetpoint)) м/с", "Направление: \(t.direction.title)"])
            case .bts7960:
                let pwm = min(100, t.beltSpeed / NominalProfile.speedRange.upperBound * 100)
                return HardwareModuleState(kind: kind, status: status(risk(.current)),
                             readings: ["ШИМ: \(Int(pwm))%", "Привод: \(t.driveEnabled ? "включён" : "отключён")"])
            case .powerMonitor:
                return HardwareModuleState(kind: kind, status: status(risk(.current) || risk(.voltage)),
                             readings: ["\(f(t.voltage)) В", "\(f(t.current, 2)) А", "\(Int(t.power)) Вт"])
            case .loadCell:
                return HardwareModuleState(kind: kind, status: status(risk(.load)),
                             readings: ["Масса: \(f(t.loadKg)) кг", "Загрузка: \(Int(t.loadPercent))%"])
            case .imu:
                return HardwareModuleState(kind: kind, status: status(risk(.vibration)),
                             readings: ["Вибрация: \(f(t.vibration, 2)) мм/с"])
            case .encoder:
                return HardwareModuleState(kind: kind, status: status(false),
                             readings: ["\(Int(t.motorRPM)) об/мин", "\(f(t.beltSpeed, 2)) м/с"])
            case .pressureSensor:
                return HardwareModuleState(kind: kind, status: status(risk(.airPressure)),
                             readings: ["\(f(t.airPressure, 2)) кПа", "Подушка: \(t.airCushionOn ? "вкл" : "выкл")"])
            case .temperatureSensors:
                return HardwareModuleState(kind: kind, status: status(risk(.motorTemperature) || risk(.bearing1Temperature) || risk(.bearing2Temperature)),
                             readings: ["Двигатель: \(Int(t.motorTemperature)) °C",
                                        "Подшипник #1: \(Int(t.bearing1Temperature)) °C",
                                        "Подшипник #2: \(Int(t.bearing2Temperature)) °C"])
            case .limitSwitches:
                return HardwareModuleState(kind: kind, status: status(false),
                             readings: ["Защитная крышка: закрыта", "Концевики пресса: OK"])
            case .camera:
                return HardwareModuleState(kind: kind, status: status(false), readings: ["CAM-01 · 720p · 15 fps"])
            case .fans:
                let states = t.fans.enumerated().map { "№\($0.offset + 1): \($0.element ? "вкл" : "выкл")" }
                return HardwareModuleState(kind: kind, status: status(t.fans.contains(false) || coolingFault), readings: states)
            case .pressActuator:
                return HardwareModuleState(kind: kind, status: status(false),
                             readings: ["Ход: \(Int(t.pressPosition))%", "Циклов: \(t.cycles)"])
            }
        }
    }
}
