//
//  MashstroyRootView.swift
//  MASHSTROY AI Control
//
//  Главный экран: список модулей. Активные открывают свой дашборд,
//  запланированные показывают заглушку.
//

#if canImport(SwiftUI)
import SwiftUI
import MashstroyCore

public struct MashstroyRootView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            List(ModuleRegistry.all) { module in
                NavigationLink(value: module.kind) {
                    ModuleRow(module: module)
                }
            }
            .navigationTitle("MASHSTROY AI Control")
            .navigationDestination(for: ModuleKind.self) { kind in
                destination(for: kind)
            }
        }
        .tint(MashstroyTheme.primary)
    }

    @ViewBuilder
    private func destination(for kind: ModuleKind) -> some View {
        switch kind {
        case .smartConveyor:
            SmartConveyorDashboardView()
        case .waterTreatment, .sludgeRecycling, .labUnits:
            PlannedModuleView(module: ModuleRegistry.descriptor(for: kind))
        }
    }
}

private struct ModuleRow: View {
    let module: ModuleDescriptor

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: module.systemImage)
                .font(.title2)
                .frame(width: 40, height: 40)
                .foregroundStyle(module.availability == .active ? MashstroyTheme.accent : .secondary)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(module.title).font(.headline)
                    if module.availability == .planned {
                        Text("скоро")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
                Text(module.summary).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PlannedModuleView: View {
    let module: ModuleDescriptor

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: module.systemImage).font(.system(size: 56)).foregroundStyle(.secondary)
            Text(module.title).font(.title2.bold())
            Text(module.summary).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Text("Модуль в разработке").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(32)
        .navigationTitle(module.title)
    }
}

#Preview {
    MashstroyRootView()
}
#endif
