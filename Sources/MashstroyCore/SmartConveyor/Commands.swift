//
//  Commands.swift
//  MASHSTROY AI Control — Smart Conveyor
//
//  Команды управления и проверка безопасности перед отправкой.
//  Та же проверка должна повторяться в облаке и на ESP32: приложение —
//  лишь дополнительное средство управления, физический аварийный стоп
//  на машине остаётся основным.
//

import Foundation

public enum ConveyorCommand: Hashable, Sendable {
    case start
    case stop
    case pause
    case emergencyStop
    case resetFault
    case setSpeed(Double)
    case setControlMode(ControlMode)
    case setDirection(BeltDirection)
    case setFan(index: Int, on: Bool)
    case setAirCushion(Bool)
    case setDrive(Bool)
    case setHopperFeed(Bool)
    case pressCycle
    case runMode(OperatingMode)

    public var title: String {
        switch self {
        case .start: return "Start"
        case .stop: return "Stop"
        case .pause: return "Pause"
        case .emergencyStop: return "Emergency Stop"
        case .resetFault: return "Reset Fault"
        case .setSpeed(let v): return "Скорость \(String(format: "%.1f", v)) м/с"
        case .setControlMode(let m): return "Режим управления: \(m.title)"
        case .setDirection(let d): return "Направление: \(d.title)"
        case .setFan(let i, let on): return "Вентилятор \(i + 1): \(on ? "вкл" : "выкл")"
        case .setAirCushion(let on): return "Воздушная подушка: \(on ? "вкл" : "выкл")"
        case .setDrive(let on): return "Привод: \(on ? "вкл" : "выкл")"
        case .setHopperFeed(let on): return "Подача бункера: \(on ? "вкл" : "выкл")"
        case .pressCycle: return "Цикл пресса"
        case .runMode(let m): return "Запуск: \(m.title)"
        }
    }
}

public enum CommandResult: Hashable, Sendable {
    case accepted
    case rejected(String)

    public var isAccepted: Bool { self == .accepted }
}

public enum ConveyorSafetyPolicy {
    public static let fanCount = 3

    /// Проверяет, можно ли выполнить команду в текущем состоянии.
    public static func validate(_ command: ConveyorCommand, for t: ConveyorTelemetry) -> CommandResult {
        guard t.controllerOnline else {
            if command == .emergencyStop {
                return .rejected("ESP32 не в сети. Используйте физическую кнопку аварийного останова на установке")
            }
            return .rejected("ESP32 не в сети")
        }

        switch command {
        case .emergencyStop, .stop:
            return .accepted
        case .resetFault:
            return t.state.isLatched ? .accepted : .rejected("Нет активной аварии")
        default:
            break
        }

        if t.state == .emergency {
            return .rejected("Аварийный стоп. Устраните причину и нажмите Reset Fault")
        }

        switch command {
        case .start:
            if t.state == .fault { return .rejected("Авария: сначала нажмите Reset Fault") }
            if t.state.isMoving { return .rejected("Конвейер уже работает") }
            if !t.driveEnabled { return .rejected("Привод отключён") }
            if !t.airCushionOn { return .rejected("Включите воздушную подушку перед пуском") }
            return .accepted
        case .pause:
            return t.state.isMoving ? .accepted : .rejected("Пауза доступна только во время работы")
        case .setSpeed(let v):
            if t.controlMode == .automatic { return .rejected("В автоматическом режиме скорость задаёт производственный режим") }
            if !NominalProfile.speedRange.contains(v) {
                return .rejected("Скорость должна быть от \(NominalProfile.speedRange.lowerBound) до \(NominalProfile.speedRange.upperBound) м/с")
            }
            return .accepted
        case .setDirection(let d):
            if d == t.direction { return .accepted }
            return t.state.isMoving ? .rejected("Смена направления только после остановки") : .accepted
        case .setFan(let i, _):
            return (0..<fanCount).contains(i) ? .accepted : .rejected("Нет вентилятора №\(i + 1)")
        case .setAirCushion(let on):
            if !on && t.state.isMoving { return .rejected("Нельзя отключить воздушную подушку на ходу") }
            return .accepted
        case .pressCycle:
            if t.state == .fault { return .rejected("Авария: пресс заблокирован") }
            if t.pressPosition > 0 { return .rejected("Пресс ещё выполняет цикл") }
            return .accepted
        case .runMode:
            if t.state == .fault { return .rejected("Авария: сначала нажмите Reset Fault") }
            if !t.driveEnabled { return .rejected("Привод отключён") }
            return .accepted
        case .setControlMode, .setDrive, .setHopperFeed:
            return .accepted
        case .emergencyStop, .stop, .resetFault:
            return .accepted
        }
    }
}
