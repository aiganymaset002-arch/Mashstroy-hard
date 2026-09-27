//
//  CloudRows.swift
//  MASHSTROY AI Control
//
//  Строки таблиц MASHSTROY Cloud (supabase/migrations) и их перевод в
//  модели приложения. Здесь нет зависимости от Supabase SDK, поэтому
//  разбор покрыт обычными тестами; запросы делает модуль MashstroyCloud.
//

import Foundation

// MARK: - Участники

public struct MemberRow: Decodable, Hashable, Sendable {
    public var orgID: UUID
    public var role: String
    public var fullName: String

    enum CodingKeys: String, CodingKey {
        case orgID = "org_id", role, fullName = "full_name"
    }

    public init(orgID: UUID, role: String, fullName: String) {
        self.orgID = orgID
        self.role = role
        self.fullName = fullName
    }

    /// Самая сильная роль пользователя; без участия в организации — Viewer.
    public static func strongestRole(_ rows: [MemberRow]) -> UserRole {
        let roles = rows.compactMap { UserRole(rawValue: $0.role) }
        return UserRole.allCases.first { roles.contains($0) } ?? .viewer
    }
}

// MARK: - Машины

public struct MachineRow: Decodable, Identifiable, Hashable, Sendable {
    public struct SiteName: Decodable, Hashable, Sendable {
        public var name: String
    }

    public var id: UUID
    public var serial: String
    public var type: String
    public var name: String
    public var site: SiteName?

    enum CodingKeys: String, CodingKey {
        case id, serial, type, name, site = "sites"
    }

    public init(id: UUID, serial: String, type: String, name: String, siteName: String?) {
        self.id = id
        self.serial = serial
        self.type = type
        self.name = name
        self.site = siteName.map(SiteName.init(name:))
    }

    public var title: String { name.isEmpty ? serial : "\(serial) · \(name)" }
}

/// jsonb-объект, из которого берутся только числа (true/false → 1/0).
public struct NumericMap: Decodable, Hashable, Sendable {
    public var values: [String: Double]

    public init(_ values: [String: Double] = [:]) {
        self.values = values
    }

    struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        var result: [String: Double] = [:]
        for key in container.allKeys {
            if let number = try? container.decode(Double.self, forKey: key) {
                result[key.stringValue] = number
            } else if let flag = try? container.decode(Bool.self, forKey: key) {
                result[key.stringValue] = flag ? 1 : 0
            }
        }
        values = result
    }

    public subscript(_ key: String) -> Double? { values[key] }
}

public struct MachineStateRow: Decodable, Hashable, Sendable {
    public var machineID: UUID
    public var ts: Date
    public var state: String
    public var tripReason: String?
    public var mode: String?
    public var controlMode: String?
    public var direction: String?
    public var speed: Double?
    public var speedSetpoint: Double?
    public var cycles: Int
    public var uptimeSeconds: Double
    public var controllerOnline: Bool
    public var snapshot: NumericMap

    enum CodingKeys: String, CodingKey {
        case machineID = "machine_id", ts, state, tripReason = "trip_reason", mode
        case controlMode = "control_mode", direction, speed, speedSetpoint = "speed_setpoint"
        case cycles, uptimeSeconds = "uptime_s", controllerOnline = "controller_online", snapshot
    }

    public init(machineID: UUID, ts: Date, state: String, tripReason: String? = nil, mode: String? = nil,
                controlMode: String? = nil, direction: String? = nil, speed: Double? = nil,
                speedSetpoint: Double? = nil, cycles: Int = 0, uptimeSeconds: Double = 0,
                controllerOnline: Bool = false, snapshot: NumericMap = NumericMap()) {
        self.machineID = machineID
        self.ts = ts
        self.state = state
        self.tripReason = tripReason
        self.mode = mode
        self.controlMode = controlMode
        self.direction = direction
        self.speed = speed
        self.speedSetpoint = speedSetpoint
        self.cycles = cycles
        self.uptimeSeconds = uptimeSeconds
        self.controllerOnline = controllerOnline
        self.snapshot = snapshot
    }

    /// Телеметрия для экранов. Ключи snapshot совпадают с SensorMetric
    /// (beltSpeed, current, vibration, …) плюс beltOffset, hopperLevel,
    /// pressPosition, fan1…fan3, airCushion, drive, hopperFeed.
    public var telemetry: ConveyorTelemetry {
        let s = snapshot
        var t = ConveyorTelemetry.idle(at: ts)
        t.state = MachineState(rawValue: state) ?? .stopped
        t.tripReason = tripReason
        t.controllerOnline = controllerOnline && state != "OFFLINE"
        t.beltSpeed = speed ?? s["beltSpeed"] ?? 0
        t.speedSetpoint = speedSetpoint ?? t.speedSetpoint
        t.motorRPM = s["motorRPM"] ?? t.beltSpeed * 955
        t.current = s["current"] ?? 0
        t.voltage = s["voltage"] ?? 0
        t.loadKg = s["load"] ?? 0
        t.airPressure = s["airPressure"] ?? 0
        t.motorTemperature = s["motorTemperature"] ?? 0
        t.bearing1Temperature = s["bearing1Temperature"] ?? 0
        t.bearing2Temperature = s["bearing2Temperature"] ?? 0
        t.vibration = s["vibration"] ?? 0
        t.beltOffset = s["beltOffset"] ?? 0
        t.hopperLevel = s["hopperLevel"] ?? 0
        t.pressPosition = s["pressPosition"] ?? 0
        t.throughputKgPerHour = s["throughput"] ?? 0
        t.uptime = uptimeSeconds
        t.cycles = cycles
        t.mode = mode.flatMap(CloudNames.operatingMode) ?? t.mode
        t.controlMode = controlMode.flatMap(ControlMode.init(rawValue:)) ?? t.controlMode
        t.direction = direction.flatMap(BeltDirection.init(rawValue:)) ?? t.direction
        t.fans = (1...ConveyorSafetyPolicy.fanCount).map { (s["fan\($0)"] ?? 1) != 0 }
        t.airCushionOn = (s["airCushion"] ?? 1) != 0
        t.driveEnabled = (s["drive"] ?? 1) != 0
        t.hopperFeedOn = (s["hopperFeed"] ?? 1) != 0
        return t
    }
}

public struct DeviceRow: Decodable, Hashable, Sendable {
    public var deviceID: String
    public var kind: String
    public var fwVersion: String?
    public var ip: String?
    public var wifiSSID: String?
    public var rssi: Int?
    public var lastSeen: Date?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id", kind, fwVersion = "fw_version", ip, wifiSSID = "wifi_ssid", rssi
        case lastSeen = "last_seen"
    }

    public init(deviceID: String, kind: String, fwVersion: String? = nil, ip: String? = nil,
                wifiSSID: String? = nil, rssi: Int? = nil, lastSeen: Date? = nil) {
        self.deviceID = deviceID
        self.kind = kind
        self.fwVersion = fwVersion
        self.ip = ip
        self.wifiSSID = wifiSSID
        self.rssi = rssi
        self.lastSeen = lastSeen
    }

    public func controllerInfo(online: Bool, uptime: TimeInterval) -> ControllerInfo {
        ControllerInfo(name: "ESP32 Main Controller", deviceID: deviceID, ipAddress: ip ?? "—",
                       firmware: fwVersion ?? "—", wifiSSID: wifiSSID ?? "—", rssi: rssi ?? -100,
                       uptime: uptime, online: online)
    }
}

// MARK: - Аварии

public struct FaultRow: Decodable, Hashable, Sendable {
    public struct ComponentKind: Decodable, Hashable, Sendable { public var kind: String }
    public struct Snapshot: Decodable, Hashable, Sendable { public var evidence: [String]? }

    public struct EventRow: Decodable, Hashable, Sendable {
        public var status: String
        public var note: String
        public var createdAt: Date

        enum CodingKeys: String, CodingKey { case status, note, createdAt = "created_at" }

        public init(status: String, note: String, createdAt: Date) {
            self.status = status
            self.note = note
            self.createdAt = createdAt
        }
    }

    public var code: String
    public var kind: String
    public var detectedAt: Date
    public var title: String
    public var measured: String?
    public var normal: String?
    public var aiDiagnosis: String?
    public var probability: Double?
    public var risk: String
    public var action: String?
    public var status: String
    public var technicianNote: String?
    public var component: ComponentKind?
    public var snapshot: Snapshot?
    public var events: [EventRow]?

    enum CodingKeys: String, CodingKey {
        case code, kind, detectedAt = "detected_at", title, measured, normal, aiDiagnosis = "ai_diagnosis"
        case probability, risk, action, status, technicianNote = "technician_note"
        case component = "components", snapshot, events = "fault_events"
    }

    /// Колонки для запроса вместе с узлом и журналом статусов.
    public static let selectColumns =
        "code,kind,detected_at,title,measured,normal,ai_diagnosis,probability,risk,action,status,technician_note,snapshot,components(kind),fault_events(status,note,created_at)"

    public init(code: String, kind: String, detectedAt: Date, title: String, measured: String? = nil,
                normal: String? = nil, aiDiagnosis: String? = nil, probability: Double? = nil, risk: String,
                action: String? = nil, status: String, technicianNote: String? = nil, componentKind: String? = nil,
                evidence: [String]? = nil, events: [EventRow]? = nil) {
        self.code = code
        self.kind = kind
        self.detectedAt = detectedAt
        self.title = title
        self.measured = measured
        self.normal = normal
        self.aiDiagnosis = aiDiagnosis
        self.probability = probability
        self.risk = risk
        self.action = action
        self.status = status
        self.technicianNote = technicianNote
        self.component = componentKind.map(ComponentKind.init(kind:))
        self.snapshot = evidence.map(Snapshot.init(evidence:))
        self.events = events
    }

    public var record: FaultRecord {
        let log = (events ?? [])
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { e in FaultStatus(rawValue: e.status).map { FaultStatusChange(status: $0, date: e.createdAt, note: e.note) } }
        return FaultRecord(
            id: code,
            kind: DiagnosisKind(rawValue: kind) ?? .other,
            component: component.flatMap { CloudNames.component($0.kind) } ?? .controller,
            detectedAt: detectedAt,
            title: title,
            measured: measured ?? "—",
            normal: normal ?? "—",
            evidence: snapshot?.evidence ?? [],
            aiDiagnosis: aiDiagnosis ?? "",
            probability: probability ?? 0,
            risk: CloudNames.risk(risk),
            action: action ?? "",
            status: FaultStatus(rawValue: status) ?? .new,
            technicianNote: technicianNote ?? "",
            log: log)
    }
}

public struct FaultStatusUpdate: Encodable, Sendable {
    public var status: String
    public var technicianNote: String?

    enum CodingKeys: String, CodingKey { case status, technicianNote = "technician_note" }

    public init(status: FaultStatus, note: String) {
        self.status = status.rawValue
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        self.technicianNote = trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Команды

public struct CommandParams: Encodable, Hashable, Sendable {
    public var speed: Double?
    public var mode: String?
    public var direction: String?
    public var fan: Int?
    public var on: Bool?
}

public struct CommandInsert: Encodable, Hashable, Sendable {
    public var machineID: UUID
    public var action: String
    public var params: CommandParams

    enum CodingKeys: String, CodingKey { case machineID = "machine_id", action, params }

    public init(machineID: UUID, command: ConveyorCommand) {
        self.machineID = machineID
        var p = CommandParams()
        switch command {
        case .start: action = "start"
        case .stop: action = "stop"
        case .pause: action = "pause"
        case .emergencyStop: action = "emergency_stop"
        case .resetFault: action = "reset_fault"
        case .setSpeed(let v): action = "set_speed"; p.speed = v
        case .setControlMode(let m): action = "set_control_mode"; p.mode = m.rawValue
        case .setDirection(let d): action = "set_direction"; p.direction = d.rawValue
        case .setFan(let i, let on): action = "set_fan"; p.fan = i + 1; p.on = on
        case .setAirCushion(let on): action = "set_air_cushion"; p.on = on
        case .setDrive(let on): action = "set_drive"; p.on = on
        case .setHopperFeed(let on): action = "set_hopper_feed"; p.on = on
        case .pressCycle: action = "press_cycle"
        case .runMode(let m): action = "run_mode"; p.mode = CloudNames.modeCode(m)
        }
        params = p
    }
}

// MARK: - Графики

public struct SeriesParams: Encodable, Sendable {
    public var machine: UUID
    public var metric: String
    public var from: Date
    public var to: Date
    public var bucket: String

    enum CodingKeys: String, CodingKey {
        case machine = "p_machine", metric = "p_metric", from = "p_from", to = "p_to", bucket = "p_bucket"
    }

    public init(machine: UUID, metric: SensorMetric, range: HistoryRange, now: Date) {
        self.machine = machine
        self.metric = metric.rawValue
        self.from = now.addingTimeInterval(-range.duration)
        self.to = now
        self.bucket = range.bucket
    }
}

public struct SeriesRow: Decodable, Hashable, Sendable {
    public var bucket: Date
    public var avgValue: Double?

    enum CodingKeys: String, CodingKey { case bucket, avgValue = "avg_value" }

    public init(bucket: Date, avgValue: Double?) {
        self.bucket = bucket
        self.avgValue = avgValue
    }

    public var point: MetricPoint? { avgValue.map { MetricPoint(date: bucket, value: $0) } }
}

// MARK: - Имена в базе

public enum CloudNames {
    public static func modeCode(_ mode: OperatingMode) -> String {
        switch mode {
        case .ecoBrick: return "eco_brick"
        case .sludgeProcessing: return "sludge_processing"
        case .materialTransport: return "material_transport"
        case .research: return "research"
        }
    }

    public static func operatingMode(_ code: String) -> OperatingMode? {
        OperatingMode.allCases.first { modeCode($0) == code } ?? OperatingMode(rawValue: code)
    }

    public static func component(_ kind: String) -> MachineComponent? {
        switch kind {
        case "air_chamber": return .airChamber
        case "press_actuator": return .pressActuator
        default: return MachineComponent(rawValue: kind)
        }
    }

    public static func risk(_ value: String) -> RiskLevel {
        switch value {
        case "critical": return .critical
        case "high": return .high
        case "medium": return .medium
        default: return .low
        }
    }
}
