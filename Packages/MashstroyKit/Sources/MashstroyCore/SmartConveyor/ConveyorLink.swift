//
//  ConveyorLink.swift
//  MASHSTROY AI Control — Smart Conveyor
//
//  Граница между приложением и оборудованием. Сейчас её реализует
//  ConveyorSimulator. Для реальной установки появится CloudConveyorLink:
//  Mobile App → MASHSTROY Cloud → Secure Gateway → ESP32.
//  Приложение не шлёт команды двигателю напрямую; критические защиты
//  работают локально на ESP32 даже без интернета.
//

import Foundation

public struct ConveyorSnapshot: Hashable, Sendable {
    public var machineID: String
    public var telemetry: ConveyorTelemetry
    public var controller: ControllerInfo
    public var modules: [HardwareModuleState]
    public var visionEvents: [VisionEvent]

    public init(machineID: String, telemetry: ConveyorTelemetry, controller: ControllerInfo,
                modules: [HardwareModuleState], visionEvents: [VisionEvent]) {
        self.machineID = machineID
        self.telemetry = telemetry
        self.controller = controller
        self.modules = modules
        self.visionEvents = visionEvents
    }
}

public protocol ConveyorLink: AnyObject {
    var machineID: String { get }
    /// Последний снимок телеметрии, модулей и событий камеры.
    func poll() async throws -> ConveyorSnapshot
    /// Команда проходит ConveyorSafetyPolicy на стороне приложения и повторно на стороне оборудования.
    func send(_ command: ConveyorCommand) async throws -> CommandResult
    /// История показателя за период (для Live приложение использует свой буфер).
    func history(of metric: SensorMetric, range: HistoryRange) async throws -> [MetricPoint]
}
