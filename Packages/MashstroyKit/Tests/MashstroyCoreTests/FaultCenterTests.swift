import XCTest
@testable import MashstroyCore

final class FaultCenterTests: XCTestCase {
    private func diagnosis(_ kind: DiagnosisKind, risk: RiskLevel = .high) -> Diagnosis {
        Diagnosis(kind: kind, component: .motor, title: "Повышенный ток", evidence: ["Ток ↑ 45%"],
                  cause: "Возможное заклинивание / подшипник", probability: 0.8, checks: ["Привод"],
                  risk: risk, action: "Остановить установку и проверить привод",
                  measured: "Current: 5.2 A", normal: "2.8–3.6 A")
    }

    func testIDFormat() {
        XCTAssertEqual(FaultCenter.makeID(year: 2026, number: 41), "FAULT-2026-00041")
    }

    func testRegisterNumbersAndDeduplicates() {
        let year = Calendar.current.component(.year, from: testStart)
        var center = FaultCenter(lastNumber: 40, year: year)
        let created = center.register([diagnosis(.motorOverload), diagnosis(.beltJam)], at: testStart)
        XCTAssertEqual(created.map(\.id), [FaultCenter.makeID(year: year, number: 41), FaultCenter.makeID(year: year, number: 42)])
        XCTAssertTrue(center.register([diagnosis(.motorOverload)], at: testStart).isEmpty)
        XCTAssertTrue(center.register([diagnosis(.beltOverload, risk: .low)], at: testStart).isEmpty)
        XCTAssertEqual(center.openCount, 2)
        XCTAssertEqual(center.records.first?.kind, .beltJam)
    }

    func testLifecycleRequiresTechnicianNoteToResolve() throws {
        var center = FaultCenter()
        let id = try XCTUnwrap(center.register([diagnosis(.motorOverload)], at: testStart).first?.id)
        XCTAssertEqual(try center.advance(id: id, note: "", at: testStart).status, .accepted)
        XCTAssertEqual(try center.advance(id: id, note: "Снял кожух", at: testStart).status, .repairing)
        XCTAssertThrowsError(try center.advance(id: id, note: "  ", at: testStart)) {
            XCTAssertEqual($0 as? FaultCenterError, .noteRequired)
        }
        let resolved = try center.advance(id: id, note: "Заклинил подшипник барабана, заменён", at: testStart)
        XCTAssertEqual(resolved.status, .resolved)
        XCTAssertEqual(resolved.technicianNote, "Заклинил подшипник барабана, заменён")
        XCTAssertEqual(resolved.log.map(\.status), [.new, .accepted, .repairing, .resolved])
        XCTAssertThrowsError(try center.advance(id: id, note: "x", at: testStart)) {
            XCTAssertEqual($0 as? FaultCenterError, .alreadyResolved)
        }

        // После устранения тот же диагноз снова заводит карточку.
        XCTAssertEqual(center.register([diagnosis(.motorOverload)], at: testStart).count, 1)
    }

    func testUnknownID() {
        var center = FaultCenter()
        XCTAssertThrowsError(try center.advance(id: "FAULT-0000-00000", note: "", at: testStart))
    }
}
