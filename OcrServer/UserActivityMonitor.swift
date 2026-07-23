//
//  UserActivityMonitor.swift
//  OcrServer
//

import SwiftUI
import UIKit

struct UserActivityMonitor: UIViewRepresentable {
    let onActivity: @MainActor () -> Void

    func makeUIView(context: Context) -> UserActivityProbeView {
        let view = UserActivityProbeView()
        view.onActivity = onActivity
        return view
    }

    func updateUIView(_ uiView: UserActivityProbeView, context: Context) {
        uiView.onActivity = onActivity
    }
}

final class UserActivityProbeView: UIView {
    var onActivity: @MainActor () -> Void = {}

    private weak var monitoredWindow: UIWindow?
    private var activityRecognizer: UserActivityGestureRecognizer?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        detachRecognizer()

        guard let window else { return }
        let recognizer = UserActivityGestureRecognizer { [weak self] in
            self?.onActivity()
        }
        window.addGestureRecognizer(recognizer)
        monitoredWindow = window
        activityRecognizer = recognizer
    }

    deinit {
        detachRecognizer()
    }

    private func detachRecognizer() {
        if let activityRecognizer {
            monitoredWindow?.removeGestureRecognizer(activityRecognizer)
        }
        monitoredWindow = nil
        activityRecognizer = nil
    }
}

final class UserActivityGestureRecognizer: UIGestureRecognizer {
    private let onActivity: @MainActor () -> Void

    init(onActivity: @escaping @MainActor () -> Void) {
        self.onActivity = onActivity
        super.init(target: nil, action: nil)
        configureTouchObservation()
    }

    required init?(coder: NSCoder) {
        onActivity = {}
        super.init(coder: coder)
        configureTouchObservation()
    }

    private func configureTouchObservation() {
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onActivity()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }
}
