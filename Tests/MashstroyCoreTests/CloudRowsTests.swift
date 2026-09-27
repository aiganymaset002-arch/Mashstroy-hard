import XCTest
@testable import MashstroyCore

final class CloudRowsTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func testStrongestRole() {
        let org = UUID()
        XCTAssertEqual(MemberRow.strongestRole([]), .viewer)
        XCTAssertEqual(MemberRow.strongestRole([
            MemberRow(orgID: org, role: "technician", fullName: ""),
            MemberRow(orgID: org, role: "engineer", fullName: "")
        ]), .engineer)
        XCTAssertEqual(MemberRow.strongestRole([MemberRow(orgID: org, role: "unknown", fullName: "")]), .viewer)
    }

    func testMachineStateDecodesAndMapsToTelemetry() throws {
        let json = """
        {"machine_id":"00000000-0000-4000-8000-000000001001","ts":"2026-09-27T10:00:00Z","state":"RUNNING",
         "trip_reason":null,"mode":"sludge_processing","control_mode":"automatic","direction":"reverse",
         "speed":1.2,"speed_setpoint":1.5,"cycles":42,"uptime_s":3600,"controller_online":true,
         "snapshot":{"current":7.5,"vibration":2.1,"fan2":false,"airCushion":true,"label":"x"}}
        """
        let row = try decoder.decode(MachineStateRow.self, from: Data(json.utf8))
        XCTAssertEqual(row.snapshot["fan2"], 0)
        XCTAssertNil(row.snapshot["label"])

        let t = row.telemetry
        XCTAssertEqual(t.state, .running)
        XCTAssertTrue(t.controllerOnline)
        XCTAssertEqual(t.beltSpeed, 1.2)
        XCTAssertEqual(t.speedSetpoint, 1.5)
        XCTAssertEqual(t.current, 7.5)
        XCTAssertEqual(t.vibration, 2.1)
        XCTAssertEqual(t.cycles, 42)
        XCTAssertEqual(t.uptime, 3600)
        XCTAssertEqual(t.mode, .sludgeProcessing)
        XCTAssertEqual(t.controlMode, .automatic)
        XCTAssertEqual(t.direction, .reverse)
        XCTAssertEqual(t.fans, [true, false, true])
        XCTAssertTrue(t.airCushionOn)
    }

    func testOfflineStateMeansControllerOffline() {
        let row = MachineStateRow(machineID: UUID(), ts: Date(), state: "OFFLINE", controllerOnline: true)
        XCTAssertFalse(row.telemetry.controllerOnline)
    }

    func testFaultRowBuildsRecordWithOrderedLog() throws {
        let json = """
        {"code":"F-1","kind":"bearingDegradation","detected_at":"2026-09-27T10:00:00Z","title":"Износ",
         "measured":"4.1 мм/с","normal":"< 2.8","ai_diagnosis":"Подшипник #2","probability":0.82,"risk":"high",
         "action":"Проверить смазку","status":"accepted","technician_note":null,
         "snapshot":{"evidence":["Вибрация ↑ 34%"]},"components":{"kind":"bearing2"},
         "fault_events":[{"status":"accepted","note":"","created_at":"2026-09-27T10:05:00Z"},
                         {"status":"new","note":"","created_at":"2026-09-27T10:00:00Z"}]}
        """
        let record = try decoder.decode(FaultRow.self, from: Data(json.utf8)).record
        XCTAssertEqual(record.id, "F-1")
        XCTAssertEqual(record.kind, .bearingDegradation)
        XCTAssertEqual(record.component, .bearing2)
        XCTAssertEqual(record.risk, .high)
        XCTAssertEqual(record.status, .accepted)
        XCTAssertEqual(record.evidence, ["Вибрация ↑ 34%"])
        XCTAssertEqual(record.log.map(\.status), [.new, .accepted])
    }

    func testUnknownFaultKindFallsBack() {
        let row = FaultRow(code: "F-2", kind: "futureKind", detectedAt: Date(), title: "?", risk: "weird",
                           status: "new", componentKind: "air_chamber")
        XCTAssertEqual(row.record.kind, .other)
        XCTAssertEqual(row.record.component, .airChamber)
        XCTAssertEqual(row.record.risk, .low)
    }

    func testCommandInsertEncoding() throws {
        let id = UUID()
        func json(_ c: ConveyorCommand) throws -> [String: Any] {
            let data = try JSONEncoder().encode(CommandInsert(machineID: id, command: c))
            return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        let stop = try json(.emergencyStop)
        XCTAssertEqual(stop["action"] as? String, "emergency_stop")
        XCTAssertEqual(stop["machine_id"] as? String, id.uuidString)

        let mode = try json(.runMode(.ecoBrick))
        XCTAssertEqual(mode["action"] as? String, "run_mode")
        XCTAssertEqual((mode["params"] as? [String: Any])?["mode"] as? String, "eco_brick")

        let fan = try json(.setFan(index: 0, on: false))
        XCTAssertEqual((fan["params"] as? [String: Any])?["fan"] as? Int, 1)
        XCTAssertEqual((fan["params"] as? [String: Any])?["on"] as? Bool, false)
    }

    func testModeCodesRoundTrip() {
        for mode in OperatingMode.allCases {
            XCTAssertEqual(CloudNames.operatingMode(CloudNames.modeCode(mode)), mode)
        }
    }

    func testFaultStatusUpdateDropsEmptyNote() {
        XCTAssertNil(FaultStatusUpdate(status: .accepted, note: "  ").technicianNote)
        XCTAssertEqual(FaultStatusUpdate(status: .resolved, note: " Заменён ").technicianNote, "Заменён")
    }
}
