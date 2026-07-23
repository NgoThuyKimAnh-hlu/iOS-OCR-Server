//
//  DisplayModeController.swift
//  OcrServer
//

import Combine
import SwiftUI
import UIKit

@MainActor
final class DisplayModeController: ObservableObject {
    static let shared = DisplayModeController()

    @Published private(set) var isBlackout = false

    private var brightnessBeforeBlackout: CGFloat?
    private var sceneIsActive = false

    private init() {}

    func enterBlackout() {
        guard !isBlackout else {
            applyActiveDisplayState()
            return
        }

        brightnessBeforeBlackout = UIScreen.main.brightness
        isBlackout = true
        applyActiveDisplayState()
    }

    func exitBlackout() {
        guard isBlackout else { return }

        isBlackout = false
        restoreBrightness(keepSavedValue: false)
        if sceneIsActive {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    func sceneActivityChanged(isActive: Bool) {
        sceneIsActive = isActive
        if isActive {
            applyActiveDisplayState()
        } else if isBlackout {
            restoreBrightness(keepSavedValue: true)
        }
    }

    private func applyActiveDisplayState() {
        guard sceneIsActive else { return }

        UIApplication.shared.isIdleTimerDisabled = true
        if isBlackout {
            UIScreen.main.brightness = 0
        }
    }

    private func restoreBrightness(keepSavedValue: Bool) {
        guard let brightnessBeforeBlackout else { return }

        UIScreen.main.brightness = brightnessBeforeBlackout
        if !keepSavedValue {
            self.brightnessBeforeBlackout = nil
        }
    }
}

struct BlackoutView: View {
    @ObservedObject private var displayMode = DisplayModeController.shared

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
            .onTapGesture(count: 2) {
                displayMode.exitBlackout()
            }
            .accessibilityElement()
            .accessibilityLabel("Blackout active")
            .accessibilityHint("Double-tap to return to the console")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                displayMode.exitBlackout()
            }
    }
}

extension View {
    @ViewBuilder
    func blackoutCovered(when isBlackout: Bool) -> some View {
        accessibilityHidden(isBlackout)
            .overlay {
                if isBlackout {
                    BlackoutView()
                }
            }
    }
}
