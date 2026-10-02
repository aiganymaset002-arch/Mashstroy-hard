//
//  MashstroyAIControlApp.swift
//  MASHSTROY AI Control
//

import SwiftUI
#if canImport(MashstroyUI)
import MashstroyUI
#endif

@main
struct MashstroyAIControlApp: App {
    var body: some Scene {
        WindowGroup {
            MashstroyRootView()
        }
    }
}
