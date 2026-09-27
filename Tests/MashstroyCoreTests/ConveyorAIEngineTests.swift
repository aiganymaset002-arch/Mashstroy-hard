import XCTest
@testable import MashstroyCore

final class ConveyorAIEngineTests: XCTestCase {
    private let engine = ConveyorAIEngine()
    private let limits = ConveyorLimits.standard

    private func reading(status: ConveyorStatus = .running, speed: Double = 1.8, load: Double = 70,
                         temp: Double = 55, vibration: Double = 2.5, offset: Double = 0) -> ConveyorReading {
        ConveyorReading(status: status, speed: speed, loadPercent: load,
                        motorTemperature: temp, vibration: vibration, beltAlignmentOffset: offset)
    }

    func testNormalOperationHasNoAlerts() {
        let result = engine.analyze(current: reading(), history: [], limits: limits)
        XCTAssertTrue(result.alerts.isEmpty)
        XCTAssertEqual(result.healthScore, 100)
        XCTAssertEqual(result.recommendations.first?.id, "all-good")
    }

    func testOverloadIsCriticalWithFeedRecommendation() {
        let result = engine.analyze(current: reading(load: 115), history: [], limits: limits)
        XCTAssertEqual(result.alerts.first?.id, "overload")
        XCTAssertEqual(result.alerts.first?.severity, .critical)
        XCTAssertTrue(result.recommendations.contains { $0.id == "overload-feed" })
        XCTAssertLessThan(result.healthScore, 100)
    }

    func testUnderloadSuggestsLowerSpeed() {
        let result = engine.analyze(current: reading(load: 15), history: [], limits: limits)
        XCTAssertTrue(result.recommendations.contains { $0.id == "underload-speed" })
    }

    func testRisingMotorTemperatureTrend() {
        let history = [60.0, 62, 64, 66].map { reading(temp: $0) }
        let result = engine.analyze(current: reading(temp: 68), history: history, limits: limits)
        XCTAssertTrue(result.recommendations.contains { $0.id == "motor-trend" })
    }

    func testFaultAndVibrationAreSortedBySeverity() {
        let result = engine.analyze(current: reading(status: .fault, vibration: 8, offset: 20), history: [], limits: limits)
        XCTAssertEqual(result.alerts.first?.severity, .critical)
        XCTAssertEqual(result.alerts.last?.severity, .warning)
        XCTAssertTrue(result.healthScore <= 30)
    }

    func testSimulatorIsDeterministic() {
        let a = SimulatedConveyorSource(seed: 7)
        let b = SimulatedConveyorSource(seed: 7)
        for _ in 0..<20 {
            let ra = a.nextReading(), rb = b.nextReading()
            XCTAssertEqual(ra.loadPercent, rb.loadPercent)
            XCTAssertEqual(ra.status, rb.status)
        }
    }

    func testRegistryHasActiveConveyorAndPlannedModules() {
        XCTAssertEqual(ModuleRegistry.descriptor(for: .smartConveyor).availability, .active)
        XCTAssertEqual(ModuleRegistry.all.filter { $0.availability == .planned }.count, 3)
    }
}
