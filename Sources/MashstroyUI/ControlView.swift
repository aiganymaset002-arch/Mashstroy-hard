//
//  ControlView.swift
//  MASHSTROY AI Control — Управление конвейером
//
//  Каждая команда проходит ConveyorSafetyPolicy. Физическая кнопка
//  аварийного останова на машине остаётся основной.
//

#if canImport(SwiftUI)
import SwiftUI
import MashstroyCore

struct ControlView: View {
    let user: AppUser
    @EnvironmentObject private var store: ConveyorStore
    @State private var speed = 1.2

    private var canControl: Bool { user.can(.controlMachine) }

    var body: some View {
        Form {
            if let t = store.telemetry {
                statusSection(t)
                emergencySection
                mainButtons(t)
                speedSection(t)
                modesSection(t)
                equipmentSection(t)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Управление")
        .onAppear { if let t = store.telemetry { speed = t.speedSetpoint } }
    }

    private func statusSection(_ t: ConveyorTelemetry) -> some View {
        Section {
            HStack {
                StateBadge(state: t.state)
                Spacer()
                Text("\(String(format: "%.2f", t.beltSpeed)) м/с").monospacedDigit()
            }
            if let reason = t.tripReason, t.state.isLatched {
                Label(reason, systemImage: "exclamationmark.octagon.fill").foregroundStyle(MashstroyTheme.critical)
            }
            if let feedback = store.feedback {
                Label(feedback.text, systemImage: feedback.result.isAccepted ? "checkmark.circle" : "xmark.octagon")
                    .font(.footnote)
                    .foregroundStyle(feedback.result.isAccepted ? MashstroyTheme.ok : MashstroyTheme.critical)
            }
            if !canControl {
                Text("Роль \(user.role.title): управление недоступно.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var emergencySection: some View {
        Section {
            Button {
                send(.emergencyStop)
            } label: {
                Label("EMERGENCY STOP", systemImage: "exclamationmark.octagon.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(MashstroyTheme.critical)
            .disabled(!user.can(.emergencyStop))
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        } footer: {
            Text("Основной аварийный стоп — физическая кнопка на установке. ESP32 сам останавливает конвейер при превышении тока, температуры, вибрации, заклинивании и открытой крышке, даже без связи.")
        }
    }

    private func mainButtons(_ t: ConveyorTelemetry) -> some View {
        Section("Пуск и остановка") {
            HStack(spacing: 10) {
                controlButton("Start", "play.fill", MashstroyTheme.ok) { send(.start) }
                controlButton("Pause", "pause.fill", MashstroyTheme.accent) { send(.pause) }
                controlButton("Stop", "stop.fill", .gray) { send(.stop) }
            }
            .buttonStyle(.borderless)
            Button {
                send(.resetFault)
            } label: {
                Label("Reset Fault", systemImage: "arrow.counterclockwise")
            }
            .disabled(!canControl && !user.can(.manageFaults))
        }
    }

    private func controlButton(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.caption.bold())
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(.white)
            .background(color.opacity(canControl ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!canControl)
    }

    private func speedSection(_ t: ConveyorTelemetry) -> some View {
        Section("Скорость и режим управления") {
            Picker("Управление", selection: Binding(
                get: { t.controlMode },
                set: { send(.setControlMode($0)) }
            )) {
                ForEach(ControlMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading) {
                HStack {
                    Text("Задание скорости")
                    Spacer()
                    Text("\(String(format: "%.1f", speed)) м/с").monospacedDigit()
                }
                Slider(value: $speed, in: NominalProfile.speedRange, step: 0.1, onEditingChanged: { editing in
                    if !editing { send(.setSpeed(speed)) }
                })
            }
            .disabled(!canControl || t.controlMode == .automatic)

            Picker("Направление", selection: Binding(
                get: { t.direction },
                set: { send(.setDirection($0)) }
            )) {
                ForEach(BeltDirection.allCases) { Text($0.title).tag($0) }
            }
        }
        .disabled(!canControl)
    }

    private func modesSection(_ t: ConveyorTelemetry) -> some View {
        Section("Производственные режимы") {
            ForEach(OperatingMode.allCases) { mode in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.title).font(.subheadline.bold())
                        Text("\(mode.summary) · \(String(format: "%.1f", mode.nominalSpeed)) м/с").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if t.mode == mode && t.state.isMoving {
                        Badge(text: "активен", color: MashstroyTheme.ok)
                    } else {
                        Button("Запустить") { send(.runMode(mode)) }.buttonStyle(.bordered)
                    }
                }
            }
        }
        .disabled(!canControl)
    }

    private func equipmentSection(_ t: ConveyorTelemetry) -> some View {
        Section("Оборудование") {
            Toggle("Привод", isOn: binding(t.driveEnabled) { .setDrive($0) })
            Toggle("Воздушная подушка", isOn: binding(t.airCushionOn) { .setAirCushion($0) })
            Toggle("Подача из бункера", isOn: binding(t.hopperFeedOn) { .setHopperFeed($0) })
            ForEach(t.fans.indices, id: \.self) { i in
                Toggle("Вентилятор \(i + 1)", isOn: binding(t.fans[i]) { .setFan(index: i, on: $0) })
            }
            HStack {
                Text("Пресс: ход \(Int(t.pressPosition))%")
                Spacer()
                Button("Цикл пресса") { send(.pressCycle) }.buttonStyle(.bordered)
            }
            Text("Клапаны и насосы появятся с модулями очистки воды и переработки шлама.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .disabled(!canControl)
    }

    private func binding(_ value: Bool, _ command: @escaping (Bool) -> ConveyorCommand) -> Binding<Bool> {
        Binding(get: { value }, set: { send(command($0)) })
    }

    private func send(_ command: ConveyorCommand) {
        Task {
            await store.send(command)
            if case .setControlMode = command, let t = store.telemetry { speed = t.speedSetpoint }
        }
    }
}
#endif
