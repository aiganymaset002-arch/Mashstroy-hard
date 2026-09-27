//
//  SensorsView.swift
//  MASHSTROY AI Control — ESP32 и оборудование
//

#if canImport(SwiftUI)
import SwiftUI
import MashstroyCore

struct SensorsView: View {
    @EnvironmentObject private var store: ConveyorStore
    @State private var notice: String?

    var body: some View {
        List {
            if let snap = store.snapshot {
                controllerSection(snap.controller)
                Section("Модули") {
                    ForEach(snap.modules) { module in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: module.kind.systemImage)
                                .frame(width: 28)
                                .foregroundStyle(MashstroyTheme.color(for: module.status))
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(module.kind.title).font(.subheadline.bold())
                                    Spacer()
                                    StatusDot(status: module.status)
                                }
                                Text(module.kind.role).font(.caption).foregroundStyle(.secondary)
                                Text(module.readings.joined(separator: " · ")).font(.caption.monospacedDigit())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Датчики и ESP32")
        .alert("Симулятор", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(notice ?? "")
        }
    }

    private func controllerSection(_ c: ControllerInfo) -> some View {
        Section(c.name) {
            LabeledContent("Состояние") { StatusDot(status: c.online ? .online : .offline) }
            LabeledContent("Device ID", value: c.deviceID)
            LabeledContent("IP", value: c.ipAddress)
            LabeledContent("Firmware", value: c.firmware)
            LabeledContent("Wi-Fi", value: c.wifiSSID)
            LabeledContent("RSSI", value: c.online ? "\(c.rssi) дБм · \(c.signalQuality)" : "—")
            LabeledContent("Uptime", value: Formatters.duration(c.uptime))
            Button("Перезагрузить контроллер") {
                notice = "Перезагрузка будет доступна после подключения реального ESP32 через MASHSTROY Cloud."
            }
            Button("OTA-обновление прошивки") {
                notice = "OTA-обновление будет доступно после подключения реального ESP32 через MASHSTROY Cloud."
            }
        }
    }
}
#endif
