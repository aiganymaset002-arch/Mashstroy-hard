import XCTest
@testable import MashstroyCore

final class SimulatorTests: XCTestCase {
    func testStartReachesSetpointWithNormalReadings() {
        let (sim, _) = warmedUpSimulator()
        let t = sim.telemetry
        XCTAssertEqual(t.state, .running)
        XCTAssertEqual(t.beltSpeed, t.speedSetpoint, accuracy: 0.05)
        XCTAssertTrue(NominalProfile.currentRange.contains(t.current))
        XCTAssertLessThan(t.vibration, NominalProfile.maxVibration)
        XCTAssertGreaterThan(t.throughputKgPerHour, 0)
        XCTAssertGreaterThan(t.uptime, 0)
    }

    func testEmergencyStopHaltsImmediately() {
        let (sim, _) = warmedUpSimulator(ticks: 20)
        XCTAssertEqual(sim.apply(.emergencyStop), .accepted)
        XCTAssertEqual(sim.telemetry.state, .emergency)
        XCTAssertEqual(sim.telemetry.beltSpeed, 0)
        XCTAssertFalse(sim.apply(.start).isAccepted)
        XCTAssertEqual(sim.apply(.resetFault), .accepted)
        XCTAssertEqual(sim.telemetry.state, .stopped)
    }

    func testJamTripsLocalProtectionAndBlocksReset() {
        var (sim, history) = warmedUpSimulator()
        sim.inject(.jam)
        simulate(sim, ticks: 40, into: &history)
        XCTAssertEqual(sim.telemetry.state, .fault)
        XCTAssertEqual(sim.telemetry.tripReason, "Заклинивание ленты")
        XCTAssertFalse(sim.apply(.resetFault).isAccepted)
        sim.clear(.jam)
        XCTAssertEqual(sim.apply(.resetFault), .accepted)
    }

    func testPersonInZoneCausesEmergencyAndVisionEvent() {
        let (sim, _) = warmedUpSimulator(ticks: 10)
        sim.inject(.personInZone)
        sim.advance()
        XCTAssertEqual(sim.telemetry.state, .emergency)
        XCTAssertEqual(sim.snapshot().visionEvents.first?.kind, .personInZone)
    }

    func testControllerOfflineRejectsCommands() {
        let (sim, _) = warmedUpSimulator(ticks: 10)
        sim.inject(.controllerOffline)
        sim.advance()
        let snap = sim.snapshot()
        XCTAssertFalse(snap.controller.online)
        XCTAssertTrue(snap.modules.allSatisfy { $0.status == .offline })
        XCTAssertFalse(sim.apply(.stop).isAccepted)
    }

    func testRunModeAppliesModeParameters() {
        let sim = ConveyorSimulator(seed: 1, start: testStart)
        XCTAssertEqual(sim.apply(.runMode(.ecoBrick)), .accepted)
        XCTAssertEqual(sim.telemetry.mode, .ecoBrick)
        XCTAssertEqual(sim.telemetry.controlMode, .automatic)
        XCTAssertEqual(sim.telemetry.speedSetpoint, OperatingMode.ecoBrick.nominalSpeed)
        XCTAssertTrue(sim.telemetry.state.isMoving)
    }

    func testSimulatorIsDeterministic() {
        let (a, _) = warmedUpSimulator(ticks: 30, seed: 7)
        let (b, _) = warmedUpSimulator(ticks: 30, seed: 7)
        XCTAssertEqual(a.telemetry, b.telemetry)
    }

    func testSnapshotListsAllHardwareModules() {
        let (sim, _) = warmedUpSimulator(ticks: 5)
        XCTAssertEqual(sim.snapshot().modules.map(\.kind), HardwareModuleKind.allCases)
    }

    func testSyntheticHistory() async throws {
        let sim = ConveyorSimulator(seed: 3, start: testStart)
        let points = try await sim.history(of: .vibration, range: .week)
        XCTAssertEqual(points.count, HistoryRange.week.pointCount)
        XCTAssertEqual(points.last?.date, testStart)
        let live = try await sim.history(of: .vibration, range: .live)
        XCTAssertTrue(live.isEmpty)
        let summary = try XCTUnwrap(MetricSummary(points))
        XCTAssertLessThanOrEqual(summary.min, summary.average)
        XCTAssertLessThanOrEqual(summary.average, summary.max)
    }
}
