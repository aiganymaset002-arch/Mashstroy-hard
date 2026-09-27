//
//  MashstroyRootView.swift
//  MASHSTROY AI Control
//
//  Вход → вкладки: Обзор, Управление, ИИ, Аварии, Ещё
//  (датчики, камера, графики, модули, симуляция неисправностей).
//

#if canImport(SwiftUI)
import SwiftUI
import MashstroyCore

public struct MashstroyRootView: View {
    @StateObject private var session = AppSession()
    @StateObject private var store = ConveyorStore()

    public init() {}

    public var body: some View {
        Group {
            if let user = session.user {
                MainTabView(user: user)
            } else {
                LoginView()
            }
        }
        .environmentObject(session)
        .environmentObject(store)
        .tint(MashstroyTheme.primary)
    }
}

struct MainTabView: View {
    let user: AppUser
    @EnvironmentObject private var store: ConveyorStore

    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Обзор", systemImage: "gauge.with.dots.needle.67percent") }
            NavigationStack { ControlView(user: user) }
                .tabItem { Label("Управление", systemImage: "slider.horizontal.3") }
            NavigationStack { DiagnosticsView() }
                .tabItem { Label("ИИ", systemImage: "brain") }
            NavigationStack { FaultsView(user: user) }
                .tabItem { Label("Аварии", systemImage: "exclamationmark.triangle") }
                .badge(store.faults.openCount)
            NavigationStack { MoreView(user: user) }
                .tabItem { Label("Ещё", systemImage: "ellipsis.circle") }
        }
        .onAppear { store.start() }
    }
}

struct MoreView: View {
    let user: AppUser
    @EnvironmentObject private var session: AppSession

    var body: some View {
        List {
            Section("Установка") {
                if user.can(.viewHardware) {
                    NavigationLink { SensorsView() } label: { Label("Датчики и ESP32", systemImage: "cpu") }
                    NavigationLink { CameraView() } label: { Label("Камера и зрение", systemImage: "video") }
                }
                NavigationLink { HistoryView() } label: { Label("Графики и история", systemImage: "chart.xyaxis.line") }
            }
            Section("Модули MASHSTROY") {
                ForEach(ModuleRegistry.all) { module in
                    NavigationLink { ModuleDetailView(module: module) } label: { ModuleRow(module: module) }
                }
            }
            if user.can(.simulateFaults) {
                Section {
                    NavigationLink { SimulationView() } label: { Label("Симуляция неисправностей", systemImage: "wand.and.stars") }
                } footer: {
                    Text("Работает только с симулятором, пока не подключён ESP32.")
                }
            }
            Section("Профиль") {
                LabeledContent("Пользователь", value: user.name)
                LabeledContent("Роль", value: user.role.title)
                Button("Выйти", role: .destructive) { session.signOut() }
            }
        }
        .navigationTitle("Ещё")
    }
}

struct ModuleRow: View {
    let module: ModuleDescriptor

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: module.systemImage)
                .frame(width: 28)
                .foregroundStyle(module.availability == .active ? MashstroyTheme.accent : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(module.title)
                    if module.availability == .planned { Badge(text: "скоро", color: .secondary) }
                }
                Text(module.summary).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct ModuleDetailView: View {
    let module: ModuleDescriptor

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: module.systemImage).font(.system(size: 56)).foregroundStyle(.secondary)
            Text(module.title).font(.title2.bold())
            Text(module.summary).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Text(module.availability == .active ? "Модуль активен: см. вкладки Обзор и Управление" : "Модуль в разработке")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(32)
        .navigationTitle(module.title)
    }
}

struct SimulationView: View {
    @EnvironmentObject private var store: ConveyorStore

    var body: some View {
        List {
            Section {
                ForEach(SimulatedFault.allCases) { fault in
                    Toggle(fault.title, isOn: Binding(
                        get: { store.isInjected(fault) },
                        set: { store.setFault(fault, active: $0) }
                    ))
                }
            } footer: {
                Text("Неисправность развивается постепенно. Смотрите, как меняются датчики, диагнозы ИИ и карточки аварий. Локальные защиты симулятора останавливают конвейер так же, как это будет делать ESP32.")
            }
            Section {
                Button("Убрать все неисправности") { store.clearSimulatedFaults() }
            }
        }
        .navigationTitle("Симуляция")
    }
}

#Preview {
    MashstroyRootView()
}
#endif
