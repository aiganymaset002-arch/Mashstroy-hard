//
//  ConveyorStore.swift
//  MASHSTROY AI Control
//
//  Общее состояние конвейера для всех экранов: опрос ConveyorLink,
//  буфер Live-истории, ИИ-диагностика и центр аварий.
//

#if canImport(SwiftUI)
import SwiftUI
import MashstroyCore

public struct CommandFeedback: Identifiable, Equatable {
    public let id = UUID()
    public let command: ConveyorCommand
    public let result: CommandResult

    public var text: String {
        switch result {
        case .accepted: return "\(command.title): выполнено"
        case .rejected(let reason): return "\(command.title): отклонено. \(reason)"
        }
    }
}

@MainActor
public final class ConveyorStore: ObservableObject {
    @Published public private(set) var snapshot: ConveyorSnapshot?
    @Published public private(set) var liveHistory: [ConveyorTelemetry] = []
    @Published public private(set) var report: DiagnosticsReport = .empty
    @Published public private(set) var faults = FaultCenter()
    @Published public private(set) var feedback: CommandFeedback?
    @Published public private(set) var linkError: String?

    public let link: ConveyorLink
    private let engine: DiagnosticsAnalyzing
    private let interval: Duration
    private let historyLimit = HistoryRange.live.pointCount
    private var loop: Task<Void, Never>?

    public init(link: ConveyorLink = ConveyorSimulator(), engine: DiagnosticsAnalyzing = DiagnosticsEngine(),
                interval: Duration = .seconds(1)) {
        self.link = link
        self.engine = engine
        self.interval = interval
    }

    public var telemetry: ConveyorTelemetry? { snapshot?.telemetry }
    public var simulator: ConveyorSimulator? { link as? ConveyorSimulator }

    public func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(for: self.interval)
            }
        }
    }

    public func stop() {
        loop?.cancel()
        loop = nil
    }

    public func refresh() async {
        do {
            let snap = try await link.poll()
            snapshot = snap
            linkError = nil
            liveHistory.append(snap.telemetry)
            if liveHistory.count > historyLimit {
                liveHistory.removeFirst(liveHistory.count - historyLimit)
            }
            report = engine.analyze(liveHistory)
            faults.register(report.diagnoses, at: snap.telemetry.timestamp)
        } catch {
            linkError = error.localizedDescription
        }
    }

    public func send(_ command: ConveyorCommand) async {
        do {
            let result = try await link.send(command)
            feedback = CommandFeedback(command: command, result: result)
            if let simulator { snapshot = simulator.snapshot() }
        } catch {
            feedback = CommandFeedback(command: command, result: .rejected(error.localizedDescription))
        }
    }

    public func advanceFault(id: String, note: String) throws {
        try faults.advance(id: id, note: note, at: telemetry?.timestamp ?? Date())
    }

    public func history(of metric: SensorMetric, range: HistoryRange) async -> [MetricPoint] {
        if range == .live {
            return liveHistory.map { MetricPoint(date: $0.timestamp, value: metric.value(in: $0)) }
        }
        return (try? await link.history(of: metric, range: range)) ?? []
    }

    // MARK: Симуляция неисправностей

    public func isInjected(_ fault: SimulatedFault) -> Bool {
        simulator?.activeFaults.contains(fault) ?? false
    }

    public func setFault(_ fault: SimulatedFault, active: Bool) {
        guard let simulator else { return }
        objectWillChange.send()
        if active { simulator.inject(fault) } else { simulator.clear(fault) }
    }

    public func clearSimulatedFaults() {
        objectWillChange.send()
        simulator?.clearAllFaults()
    }
}
#endif
