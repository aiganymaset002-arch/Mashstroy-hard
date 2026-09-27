import Foundation
@testable import MashstroyCore

let testStart = Date(timeIntervalSince1970: 1_790_500_000) // 27.09.2026

/// Симулятор, запущенный и прогретый до установившегося режима.
func warmedUpSimulator(ticks: Int = 100, seed: UInt64 = 42) -> (ConveyorSimulator, [ConveyorTelemetry]) {
    let sim = ConveyorSimulator(seed: seed, start: testStart)
    sim.apply(.start)
    var history: [ConveyorTelemetry] = []
    for _ in 0..<ticks {
        sim.advance()
        history.append(sim.telemetry)
    }
    return (sim, history)
}

func simulate(_ sim: ConveyorSimulator, ticks: Int, into history: inout [ConveyorTelemetry]) {
    for _ in 0..<ticks {
        sim.advance()
        history.append(sim.telemetry)
    }
}
