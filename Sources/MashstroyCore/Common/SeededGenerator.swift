//
//  SeededGenerator.swift
//  MASHSTROY AI Control
//

import Foundation

/// Детерминированный генератор (xorshift64*): одинаковый seed — одинаковые данные.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2_685_821_657_736_338_717
    }

    public mutating func noise(_ amplitude: Double) -> Double {
        guard amplitude > 0 else { return 0 }
        return Double.random(in: -amplitude...amplitude, using: &self)
    }
}
