//
//  SmartConveyorViewModel.swift
//  MASHSTROY AI Control — Smart Conveyor
//

#if canImport(SwiftUI)
import SwiftUI
import MashstroyCore

@MainActor
public final class SmartConveyorViewModel: ObservableObject {
    @Published public private(set) var current: ConveyorReading?
    @Published public private(set) var history: [ConveyorReading] = []
    @Published public private(set) var analysis: ConveyorAnalysis?
    @Published public private(set) var isLive = false

    public let limits: ConveyorLimits
    private let source: ConveyorDataSource
    private let engine: ConveyorAnalyzing
    private let interval: Duration
    private let historyLimit = 60
    private var loop: Task<Void, Never>?

    public init(source: ConveyorDataSource = SimulatedConveyorSource(),
                engine: ConveyorAnalyzing = ConveyorAIEngine(),
                limits: ConveyorLimits = .standard,
                interval: Duration = .seconds(1)) {
        self.source = source
        self.engine = engine
        self.limits = limits
        self.interval = interval
    }

    public func start() {
        guard loop == nil else { return }
        isLive = true
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.refresh()
                try? await Task.sleep(for: self.interval)
            }
        }
    }

    public func stop() {
        loop?.cancel()
        loop = nil
        isLive = false
    }

    public func refresh() {
        let reading = source.nextReading()
        analysis = engine.analyze(current: reading, history: history, limits: limits)
        current = reading
        history.append(reading)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
    }
}
#endif
