//
//  CloudConveyorLink.swift
//  MASHSTROY AI Control
//
//  ConveyorLink поверх MASHSTROY Cloud: состояние машины из machine_state,
//  ESP32 из devices, графики через ms_telemetry_series, команды — записи в
//  commands (их проверяет облако, передаёт шлюз и подтверждает ESP32),
//  карточки аварий из faults.
//

import Foundation
#if canImport(MashstroyCore)
import MashstroyCore
#endif
import Supabase

public final class CloudConveyorLink: ConveyorLink, FaultBackend, @unchecked Sendable {
    public let machine: MachineRow
    public var machineID: String { machine.serial }

    private let client: SupabaseClient
    private var device: DeviceRow?
    private var lastState: MachineStateRow?

    init(client: SupabaseClient, machine: MachineRow) {
        self.client = client
        self.machine = machine
    }

    public func poll() async throws -> ConveyorSnapshot {
        let states: [MachineStateRow] = try await client.from("machine_state")
            .select()
            .eq("machine_id", value: machine.id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let state = states.first else { throw CloudError.noMachineState(machine.serial) }
        lastState = state

        if device == nil {
            let devices: [DeviceRow] = try await client.from("devices")
                .select("device_id,kind,fw_version,ip,wifi_ssid,rssi,last_seen")
                .eq("machine_id", value: machine.id.uuidString)
                .execute()
                .value
            device = devices.first { $0.kind == "esp32_main" } ?? devices.first
        }

        let telemetry = state.telemetry
        let controller = (device ?? DeviceRow(deviceID: "—", kind: "esp32_main"))
            .controllerInfo(online: telemetry.controllerOnline, uptime: state.snapshot["controllerUptime"] ?? 0)
        return ConveyorSnapshot(machineID: machine.serial, telemetry: telemetry, controller: controller,
                                modules: HardwareModuleState.derive(from: telemetry), visionEvents: [])
    }

    public func send(_ command: ConveyorCommand) async throws -> CommandResult {
        if let state = lastState {
            let verdict = ConveyorSafetyPolicy.validate(command, for: state.telemetry)
            guard verdict.isAccepted else { return verdict }
        }
        do {
            try await client.from("commands")
                .insert(CommandInsert(machineID: machine.id, command: command), returning: .minimal)
                .execute()
            return .queued
        } catch {
            return .rejected(Self.message(for: error, fallback: "Команда не записана: нет прав или связи"))
        }
    }

    public func history(of metric: SensorMetric, range: HistoryRange) async throws -> [MetricPoint] {
        guard range != .live else { return [] }
        let rows: [SeriesRow] = try await client
            .rpc("ms_telemetry_series", params: SeriesParams(machine: machine.id, metric: metric, range: range, now: Date()))
            .execute()
            .value
        return rows.compactMap(\.point)
    }

    // MARK: FaultBackend

    public func loadFaults() async throws -> [FaultRecord] {
        let rows: [FaultRow] = try await client.from("faults")
            .select(FaultRow.selectColumns)
            .eq("machine_id", value: machine.id.uuidString)
            .order("detected_at", ascending: false)
            .limit(100)
            .execute()
            .value
        return rows.map(\.record)
    }

    public func advanceFault(id: String, to status: FaultStatus, note: String) async throws {
        do {
            try await client.from("faults")
                .update(FaultStatusUpdate(status: status, note: note), returning: .minimal)
                .eq("code", value: id)
                .execute()
        } catch {
            throw CloudMessageError(message: Self.message(for: error, fallback: "Не удалось сохранить статус"))
        }
    }

    static func message(for error: Error, fallback: String) -> String {
        if let postgrest = error as? PostgrestError {
            if postgrest.code == "42501" { return "Недостаточно прав для этого действия" }
            if !postgrest.message.isEmpty { return postgrest.message }
        }
        return fallback
    }
}

struct CloudMessageError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
