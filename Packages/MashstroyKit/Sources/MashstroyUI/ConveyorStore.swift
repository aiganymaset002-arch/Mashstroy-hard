//
//  ConveyorStore.swift
//  MASHSTROY AI Control
//
//  Общее состояние конвейера для всех экранов: опрос ConveyorLink,
//  буфер Live-истории, ИИ-диагностика и центр аварий.
//

#if canImport(SwiftUI)
import SwiftUI
#if canImport(MashstroyCore)
import MashstroyCore
#endif
#if canImport(MashstroyCloud)
import MashstroyCloud
#endif

public struct CommandFeedback: Identifiable, Equatable {
    public let id = UUID()
    public let command: ConveyorCommand
    public let result: CommandResult

    public var text: String {
        switch result {
        case .accepted: return "\(command.title): выполнено"
        case .queued: return "\(command.title): отправлено, ждём подтверждения ESP32"
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
    @Published public private(set) var machines: [MachineRow] = []
    @Published public private(set) var selectedMachineID: UUID?
    @Published public private(set) var isLoadingMachines = false

    public private(set) var link: ConveyorLink
    private let engine: DiagnosticsAnalyzing
    private var cloud: MashstroyCloud?
    private var tick = 0
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
    public var isDemo: Bool { simulator != nil }
    private var faultBackend: FaultBackend? { link as? FaultBackend }

    // MARK: Источник данных

    /// Переключает все экраны на другой источник и сбрасывает накопленные данные.
    public func connect(to newLink: ConveyorLink) {
        link = newLink
        snapshot = nil
        liveHistory = []
        report = .empty
        faults = FaultCenter()
        feedback = nil
        linkError = nil
        tick = 0
        Task { await refresh() }
    }

    public func useDemo() {
        cloud = nil
        machines = []
        selectedMachineID = nil
        if !isDemo { connect(to: ConveyorSimulator()) }
    }

    /// Загружает машины, доступные пользователю по правам RLS, и подключается к первой.
    public func useCloud(_ cloud: MashstroyCloud) async {
        self.cloud = cloud
        isLoadingMachines = true
        defer { isLoadingMachines = false }
        do {
            machines = try await cloud.machines()
            if let first = machines.first(where: { $0.id == selectedMachineID }) ?? machines.first {
                select(first)
            } else {
                selectedMachineID = nil
                connect(to: NoMachineLink())
                linkError = "Нет доступных машин. Попросите администратора организации выдать доступ."
            }
        } catch {
            linkError = AppSession.describe(error)
        }
    }

    public func select(_ machine: MachineRow) {
        guard let cloud else { return }
        selectedMachineID = machine.id
        connect(to: cloud.link(for: machine))
    }

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
            if faultBackend == nil {
                faults.register(report.diagnoses, at: snap.telemetry.timestamp)
            }
        } catch {
            linkError = error.localizedDescription
        }
        if faultBackend != nil && tick % 10 == 0 {
            await reloadFaults()
        }
        tick += 1
    }

    public func reloadFaults() async {
        guard let backend = faultBackend else { return }
        do {
            faults = FaultCenter(records: try await backend.loadFaults())
        } catch {
            linkError = AppSession.describe(error)
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

    public func advanceFault(id: String, note: String) async throws {
        guard let backend = faultBackend else {
            try faults.advance(id: id, note: note, at: telemetry?.timestamp ?? Date())
            return
        }
        guard let record = faults.records.first(where: { $0.id == id }) else { throw FaultCenterError.notFound }
        let next = try FaultCenter.validateAdvance(of: record, note: note)
        try await backend.advanceFault(id: id, to: next, note: note)
        await reloadFaults()
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
/// Заглушка, пока у пользователя нет ни одной машины.
final class NoMachineLink: ConveyorLink {
    let machineID = "—"

    func poll() async throws -> ConveyorSnapshot {
        throw CloudMessage("Нет доступных машин. Попросите администратора организации выдать доступ.")
    }

    func send(_ command: ConveyorCommand) async throws -> CommandResult {
        .rejected("Машина не выбрана")
    }

    func history(of metric: SensorMetric, range: HistoryRange) async throws -> [MetricPoint] { [] }
}

struct CloudMessage: LocalizedError {
    let text: String
    init(_ text: String) { self.text = text }
    var errorDescription: String? { text }
}
#endif
