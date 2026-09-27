//
//  ConveyorDataSource.swift
//  MASHSTROY AI Control — Smart Conveyor
//
//  Источник телеметрии. Сейчас — симулятор; позже сюда подключается
//  реальный контроллер (OPC UA / Modbus через шлюз или облако).
//

import Foundation

public protocol ConveyorDataSource: AnyObject {
    func nextReading() -> ConveyorReading
}

/// Детерминированный симулятор: при одинаковом seed выдаёт одинаковые данные.
public final class SimulatedConveyorSource: ConveyorDataSource {
    private var generator: SeededGenerator
    private var tick = 0
    private var temperature = 55.0
    private var vibration = 2.5

    public init(seed: UInt64 = 42) {
        generator = SeededGenerator(seed: seed)
    }

    public func nextReading() -> ConveyorReading {
        tick += 1
        // Загрузка плавно «гуляет» по синусоиде с шумом, иногда уходит в перегруз.
        let wave = sin(Double(tick) / 12) * 30
        let load = max(0, 70 + wave + noise(8))
        let speed = max(0, 1.8 + noise(0.15))

        temperature += (load - 70) * 0.02 + noise(0.4)
        temperature = min(max(temperature, 40), 95)
        vibration = min(max(vibration + noise(0.3) + (load > 95 ? 0.2 : -0.05), 1.0), 9.0)

        let status: ConveyorStatus
        if temperature > 92 || vibration > 8.5 {
            status = .fault
        } else if load < 5 {
            status = .idle
        } else {
            status = .running
        }

        return ConveyorReading(
            status: status,
            speed: status == .fault ? 0 : speed,
            loadPercent: load,
            motorTemperature: temperature,
            vibration: vibration,
            beltAlignmentOffset: sin(Double(tick) / 20) * 12 + noise(3)
        )
    }

    private func noise(_ amplitude: Double) -> Double {
        Double.random(in: -amplitude...amplitude, using: &generator)
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }
}
