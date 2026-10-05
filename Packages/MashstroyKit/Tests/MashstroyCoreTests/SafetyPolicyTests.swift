import XCTest
@testable import MashstroyCore

final class SafetyPolicyTests: XCTestCase {
    private var idle: ConveyorTelemetry { .idle(at: testStart) }

    private func running() -> ConveyorTelemetry {
        var t = idle
        t.state = .running
        return t
    }

    func testStartAcceptedFromIdle() {
        XCTAssertEqual(ConveyorSafetyPolicy.validate(.start, for: idle), .accepted)
    }

    func testEverythingRejectedWhenControllerOffline() {
        var t = idle
        t.controllerOnline = false
        XCTAssertFalse(ConveyorSafetyPolicy.validate(.start, for: t).isAccepted)
        guard case .rejected(let reason) = ConveyorSafetyPolicy.validate(.emergencyStop, for: t) else {
            return XCTFail("E-stop over a dead link must not look accepted")
        }
        XCTAssertTrue(reason.contains("физическую кнопку"))
    }

    func testStartNeedsAirCushionAndDrive() {
        var t = idle
        t.airCushionOn = false
        XCTAssertFalse(ConveyorSafetyPolicy.validate(.start, for: t).isAccepted)
        t = idle
        t.driveEnabled = false
        XCTAssertFalse(ConveyorSafetyPolicy.validate(.start, for: t).isAccepted)
    }

    func testDirectionChangeOnlyWhenStopped() {
        XCTAssertFalse(ConveyorSafetyPolicy.validate(.setDirection(.reverse), for: running()).isAccepted)
        XCTAssertTrue(ConveyorSafetyPolicy.validate(.setDirection(.reverse), for: idle).isAccepted)
    }

    func testSpeedLimitsAndAutomaticMode() {
        XCTAssertTrue(ConveyorSafetyPolicy.validate(.setSpeed(1.0), for: idle).isAccepted)
        XCTAssertFalse(ConveyorSafetyPolicy.validate(.setSpeed(3.0), for: idle).isAccepted)
        var t = idle
        t.controlMode = .automatic
        XCTAssertFalse(ConveyorSafetyPolicy.validate(.setSpeed(1.0), for: t).isAccepted)
    }

    func testEmergencyStateBlocksEverythingButResetAndStop() {
        var t = idle
        t.state = .emergency
        XCTAssertFalse(ConveyorSafetyPolicy.validate(.start, for: t).isAccepted)
        XCTAssertFalse(ConveyorSafetyPolicy.validate(.runMode(.ecoBrick), for: t).isAccepted)
        XCTAssertTrue(ConveyorSafetyPolicy.validate(.resetFault, for: t).isAccepted)
        XCTAssertTrue(ConveyorSafetyPolicy.validate(.emergencyStop, for: running()).isAccepted)
    }

    func testResetOnlyWithActiveFault() {
        XCTAssertFalse(ConveyorSafetyPolicy.validate(.resetFault, for: idle).isAccepted)
    }

    func testAirCushionCannotBeDisabledWhileMoving() {
        XCTAssertFalse(ConveyorSafetyPolicy.validate(.setAirCushion(false), for: running()).isAccepted)
    }
}
