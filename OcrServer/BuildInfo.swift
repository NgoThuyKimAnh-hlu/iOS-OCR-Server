//
//  BuildInfo.swift
//  OcrServer
//

import Foundation

enum BuildInfo {
    private static let deviceIDKey = "compute.device.id"

    static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "Unknown"
    }

    static var buildNumber: Int {
        let value = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return value.flatMap(Int.init) ?? 0
    }

    static var gitSHA: String? {
        let value = Bundle.main.infoDictionary?["COMPUTE_BUILD_SHA"] as? String
        guard let value, !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }

    /// Stable for updates/reinstalls signed with the same app container.
    static var deviceID: String {
        let defaults = UserDefaults.standard
        if let value = defaults.string(forKey: deviceIDKey), !value.isEmpty { return value }
        let value = UUID().uuidString.lowercased()
        defaults.set(value, forKey: deviceIDKey)
        return value
    }

    static var versionStamp: String {
        let build = buildNumber > 0 ? String(buildNumber) : "Unknown"
        return "\(version) (\(build))"
    }
}
