//
//  CameraView.swift
//  MASHSTROY AI Control — Камеры и компьютерное зрение
//

#if canImport(SwiftUI)
import SwiftUI
import MashstroyCore

struct CameraView: View {
    @EnvironmentObject private var store: ConveyorStore

    var body: some View {
        List {
            if let snap = store.snapshot {
                Section {
                    CameraFeedView(telemetry: snap.telemetry, events: snap.visionEvents)
                        .frame(height: 240)
                        .listRowInsets(EdgeInsets())
                } footer: {
                    Text("Симуляция: реальный поток камеры и модель компьютерного зрения подключатся вместе с ESP32.")
                }
                Section("Что видит ИИ") {
                    if snap.visionEvents.isEmpty {
                        Text(snap.telemetry.controllerOnline ? "Лента стоит, событий нет" : "Нет видеопотока").foregroundStyle(.secondary)
                    }
                    ForEach(snap.visionEvents) { event in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.kind.title).font(.subheadline.bold())
                                Text(event.message).font(.caption)
                                Text("Уверенность: \(Formatters.percent(event.confidence))").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            RiskBadge(risk: event.risk)
                        }
                    }
                }
                Section("Контролируется") {
                    Text(VisionEventKind.allCases.map(\.title).joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Камера")
    }
}

/// Условное изображение с камеры: лента движется со скоростью телеметрии,
/// смещается при сходе, на ленте видны куски материала.
struct CameraFeedView: View {
    let telemetry: ConveyorTelemetry
    let events: [VisionEvent]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !telemetry.state.isMoving)) { context in
            GeometryReader { geo in
                let t = context.date.timeIntervalSinceReferenceDate
                let width = Double(geo.size.width)
                let height = Double(geo.size.height)
                let shift: Double = telemetry.beltSpeed * t * 60 * (telemetry.direction == .forward ? 1 : -1)
                let spacing = 36.0
                let beltHeight: Double = height * 0.45
                let beltY: Double = (height - beltHeight) / 2 + telemetry.beltOffset * 1.5

                ZStack(alignment: .topLeading) {
                    LinearGradient(colors: [Color(white: 0.12), Color(white: 0.22)], startPoint: .top, endPoint: .bottom)

                    // Лента и поперечные планки
                    Path { p in
                        p.addRect(CGRect(x: 0, y: beltY, width: width, height: beltHeight))
                    }
                    .fill(Color(white: 0.3))
                    Path { p in
                        var x = shift.truncatingRemainder(dividingBy: spacing)
                        if x > 0 { x -= spacing }
                        while x < width {
                            p.move(to: CGPoint(x: x, y: beltY))
                            p.addLine(to: CGPoint(x: x, y: beltY + beltHeight))
                            x += spacing
                        }
                    }
                    .stroke(Color(white: 0.4), lineWidth: 2)

                    // Материал
                    if telemetry.loadKg > 1 {
                        ForEach(0..<6, id: \.self) { i in
                            let raw = (Double(i) * width / 6 + shift).truncatingRemainder(dividingBy: width)
                            let x: Double = raw < 0 ? raw + width : raw
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(red: 0.62, green: 0.42, blue: 0.28))
                                .frame(width: 22, height: 14)
                                .position(x: x, y: beltY + beltHeight / 2 + Double(i % 3 - 1) * 10)
                        }
                    }

                    // Рамки событий
                    ForEach(events.filter { $0.risk >= .medium }) { event in
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(MashstroyTheme.color(for: event.risk), lineWidth: 2)
                            .frame(width: width * 0.5, height: beltHeight + 16)
                            .position(x: width / 2, y: beltY + beltHeight / 2)
                            .overlay(alignment: .topLeading) {
                                Text(event.kind.title).font(.caption2.bold()).foregroundStyle(.white)
                                    .padding(3).background(MashstroyTheme.color(for: event.risk))
                                    .offset(x: width * 0.25, y: beltY - 10)
                            }
                    }

                    HStack {
                        Circle().fill(telemetry.controllerOnline ? Color.red : Color.gray).frame(width: 8, height: 8)
                        Text(telemetry.controllerOnline ? "CAM-01 · LIVE · 720p" : "CAM-01 · НЕТ СИГНАЛА")
                        Spacer()
                        Text(telemetry.timestamp, style: .time)
                    }
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white)
                    .padding(8)
                }
            }
        }
    }
}
#endif
