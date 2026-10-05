import XCTest
@testable import MashstroyCore

final class DiagnosticsTests: XCTestCase {
    private let engine = DiagnosticsEngine()

    func testNormalOperationIsHealthy() {
        let (_, history) = warmedUpSimulator()
        let report = engine.analyze(history)
        XCTAssertTrue(report.diagnoses.isEmpty, "\(report.diagnoses.map(\.title))")
        XCTAssertGreaterThanOrEqual(report.overallHealth, 90)
        XCTAssertNil(report.nextMaintenance)
    }

    func testBearingWearIsDiagnosedWithFullExplanation() throws {
        var (sim, history) = warmedUpSimulator()
        sim.inject(.bearingWear)
        simulate(sim, ticks: 60, into: &history)
        let report = engine.analyze(history)
        let d = try XCTUnwrap(report.diagnoses.first { $0.kind == .bearingDegradation })
        XCTAssertEqual(d.component, .bearing2)
        XCTAssertTrue(d.evidence.contains { $0.hasPrefix("Вибрация ↑") })
        XCTAssertFalse(d.cause.isEmpty)
        XCTAssertFalse(d.checks.isEmpty)
        XCTAssertGreaterThan(d.probability, 0.7)
        XCTAssertGreaterThanOrEqual(d.risk, .medium)

        let health = Dictionary(uniqueKeysWithValues: report.components.map { ($0.component, $0.health) })
        XCTAssertLessThan(health[.bearing2] ?? 100, health[.bearing1] ?? 0)
    }

    func testDegradingBearingGetsRemainingUsefulLife() throws {
        var (sim, history) = warmedUpSimulator()
        sim.faultGrowthPerStep = 0.01
        sim.inject(.bearingWear)
        simulate(sim, ticks: 40, into: &history)
        let report = engine.analyze(history)
        let bearing = try XCTUnwrap(report.components.first { $0.component == .bearing2 })
        XCTAssertNotNil(bearing.remainingHours)
        XCTAssertNotNil(bearing.uncertaintyHours)
        XCTAssertNotNil(report.nextMaintenance)
    }

    func testAirLeakShowsPressureProblem() {
        var (sim, history) = warmedUpSimulator()
        sim.inject(.airLeak)
        simulate(sim, ticks: 45, into: &history)
        let report = engine.analyze(history)
        XCTAssertTrue(report.diagnoses.contains { $0.kind == .airChamberLeak })
        let chamber = report.components.first { $0.component == .airChamber }
        XCTAssertLessThan(chamber?.health ?? 100, 80)
    }

    func testBeltMisalignment() {
        var (sim, history) = warmedUpSimulator()
        sim.inject(.beltMisalignment)
        simulate(sim, ticks: 45, into: &history)
        XCTAssertTrue(engine.analyze(history).diagnoses.contains { $0.kind == .beltMisalignment })
    }

    func testProtectionTripIsCritical() {
        var (sim, history) = warmedUpSimulator()
        sim.inject(.jam)
        simulate(sim, ticks: 40, into: &history)
        let report = engine.analyze(history)
        XCTAssertEqual(report.diagnoses.first?.kind, .protectionTrip)
        XCTAssertEqual(report.diagnoses.first?.risk, .critical)
    }

    func testOfflineControllerIsReported() {
        var (sim, history) = warmedUpSimulator(ticks: 20)
        sim.inject(.controllerOffline)
        simulate(sim, ticks: 2, into: &history)
        let report = engine.analyze(history)
        XCTAssertTrue(report.diagnoses.contains { $0.kind == .controllerOffline })
    }

    func testEmptyHistory() {
        XCTAssertEqual(engine.analyze([]), .empty)
    }
}
