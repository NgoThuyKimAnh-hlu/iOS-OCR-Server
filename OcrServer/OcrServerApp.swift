//
//  OcrServerApp.swift
//  OcrServer
//
//  Created by Riddle Ling on 2025/8/1.
//

import SwiftUI

@main
struct OcrServerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var serverManager = VaporServerManager()
    @StateObject private var displayMode = DisplayModeController.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(
                    serverManager: serverManager
                )
                .environmentObject(displayMode)
                TranslationServiceHost(service: TranslationService.shared)
            }
            .blackoutCovered(when: displayMode.isBlackout)
            .background {
                UserActivityMonitor {
                    displayMode.recordUserInteraction()
                }
                .frame(width: 0, height: 0)
            }
            .onChange(of: scenePhase, initial: true) { _, newPhase in
                displayMode.sceneActivityChanged(isActive: newPhase == .active)
            }
        }
    }
}
