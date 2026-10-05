//
//  FaultsView.swift
//  MASHSTROY AI Control — Fault Center
//

#if canImport(SwiftUI)
import SwiftUI
#if canImport(MashstroyCore)
import MashstroyCore
#endif

struct FaultsView: View {
    let user: AppUser
    @EnvironmentObject private var store: ConveyorStore
    @State private var showResolved = false

    private var records: [FaultRecord] {
        store.faults.records.filter { showResolved || $0.isOpen }
    }

    var body: some View {
        List {
            Picker("Фильтр", selection: $showResolved) {
                Text("Открытые (\(store.faults.openCount))").tag(false)
                Text("Все").tag(true)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            if records.isEmpty {
                Text("Неисправностей нет").foregroundStyle(.secondary)
            }
            ForEach(records) { record in
                NavigationLink {
                    FaultDetailView(id: record.id, user: user)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(record.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                            Spacer()
                            Badge(text: record.status.title, color: MashstroyTheme.color(for: record.status))
                        }
                        Text(record.title).font(.subheadline.bold())
                        HStack {
                            Text("\(record.component.title) · \(Formatters.dateTime.string(from: record.detectedAt))")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            RiskBadge(risk: record.risk)
                        }
                    }
                }
            }
        }
        .navigationTitle("Fault Center")
    }
}

struct FaultDetailView: View {
    let id: String
    let user: AppUser
    @EnvironmentObject private var store: ConveyorStore
    @State private var note = ""
    @State private var error: String?

    private var record: FaultRecord? { store.faults.records.first { $0.id == id } }

    var body: some View {
        Form {
            if let r = record {
                Section {
                    LabeledContent("Номер", value: r.id)
                    LabeledContent("Узел", value: r.component.title)
                    LabeledContent("Время", value: Formatters.dateTime.string(from: r.detectedAt))
                    LabeledContent("Ошибка", value: r.title)
                    LabeledContent("Измерено", value: r.measured)
                    LabeledContent("Норма", value: r.normal)
                    LabeledContent("Risk") { RiskBadge(risk: r.risk) }
                }
                Section("AI Diagnosis") {
                    Text(r.aiDiagnosis)
                    ForEach(r.evidence, id: \.self) { Text($0).font(.footnote.monospacedDigit()) }
                    Text("Вероятность: \(Formatters.percent(r.probability))").font(.footnote)
                }
                Section("Action") { Text(r.action) }
                Section("Статус") {
                    ForEach(Array(r.log.enumerated()), id: \.offset) { _, change in
                        HStack(alignment: .top) {
                            Circle().fill(MashstroyTheme.color(for: change.status)).frame(width: 8, height: 8).padding(.top, 6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(change.status.title).font(.subheadline.bold())
                                Text(Formatters.dateTime.string(from: change.date)).font(.caption).foregroundStyle(.secondary)
                                if !change.note.isEmpty { Text(change.note).font(.caption) }
                            }
                        }
                    }
                }
                if let action = r.status.actionTitle {
                    Section {
                        TextField(r.status.next == .resolved ? "Что реально было неисправно" : "Комментарий техника",
                                  text: $note, axis: .vertical)
                            .lineLimit(2...5)
                        if let error { Text(error).font(.footnote).foregroundStyle(MashstroyTheme.critical) }
                        Button(action) { Task { await advance(r) } }
                            .disabled(!user.can(.manageFaults))
                    } footer: {
                        Text(user.can(.manageFaults)
                             ? "Запись о реальной причине станет обучающими данными для ИИ."
                             : "Статус меняют роли Technician, Engineer и Owner.")
                    }
                } else if !r.technicianNote.isEmpty {
                    Section("Заключение техника") { Text(r.technicianNote) }
                }
            } else {
                Text("Карточка не найдена")
            }
        }
        .navigationTitle(id)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func advance(_ r: FaultRecord) async {
        do {
            try await store.advanceFault(id: r.id, note: note)
            note = ""
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
#endif
