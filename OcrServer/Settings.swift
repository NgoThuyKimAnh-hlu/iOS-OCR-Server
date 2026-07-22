//
//  Settings.swift
//  OcrServer
//
//  Created by Riddle Ling on 2025/8/8.
//

import Foundation
import Vision

struct OCRRuntimeSettingsSnapshot: Sendable {
    let confidenceThreshold: Double
    let multipassEnabled: Bool
    let roiUpscale: Double
    let correctorGroups: Set<CorrectorGroup>
    let activePack: String
    let improveEnabled: Bool
    let debugVerbose: Bool

    var improvementConfiguration: OCRImprovementConfiguration {
        OCRImprovementConfiguration(
            confidenceThreshold: confidenceThreshold,
            multipassEnabled: multipassEnabled,
            roiUpscale: roiUpscale,
            maximumROIs: 4,
            correctorGroups: correctorGroups
        )
    }
}

class Settings {
    static let shared = Settings()
    private static let correctorConfigurationVersion = 2
    private static let defaultCorrectorGroups = CorrectorGroup.allCases.map(\.rawValue)
    
    private init() {
        
    }
    
    var httpPort: Int {
        get {
            return (UserDefaults.standard.object(forKey: "httpPort") as? Int) ?? 8000
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "httpPort")
        }
    }
    
    var recognitionLevel: String {
        get {
            return UserDefaults.standard.string(forKey: "recognitionLevel") ?? "Accurate"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "recognitionLevel")
        }
    }
    
    var languageCorrection: Bool {
        get {
            return (
                UserDefaults.standard.object(forKey: "languageCorrection") as? Bool
            ) ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "languageCorrection")
        }
    }
    
    var automaticallyDetectsLanguage: Bool {
        get {
            return (
                UserDefaults.standard.object(forKey: "automaticallyDetectsLanguage") as? Bool
            ) ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "automaticallyDetectsLanguage")
        }
    }

    var keepAliveEnabled: Bool {
        get {
            return (
                UserDefaults.standard.object(forKey: "keepAliveEnabled") as? Bool
            ) ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "keepAliveEnabled")
        }
    }

    var adminToken: String {
        get {
            return UserDefaults.standard.string(forKey: "adminToken") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "adminToken")
        }
    }

    var improveEnabled: Bool {
        get {
            return (
                UserDefaults.standard.object(forKey: "improveEnabled") as? Bool
            ) ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "improveEnabled")
        }
    }

    var confidenceThreshold: Double {
        get {
            return (
                UserDefaults.standard.object(forKey: "confidenceThreshold") as? Double
            ) ?? 0.55
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "confidenceThreshold")
        }
    }

    var multipassEnabled: Bool {
        get {
            return (
                UserDefaults.standard.object(forKey: "multipassEnabled") as? Bool
            ) ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "multipassEnabled")
        }
    }

    var roiUpscale: Double {
        get {
            return (
                UserDefaults.standard.object(forKey: "roiUpscale") as? Double
            ) ?? 2
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "roiUpscale")
        }
    }

    var correctorGroupNames: [String] {
        get {
            let defaults = UserDefaults.standard
            if defaults.integer(forKey: "correctorConfigurationVersion")
                < Self.correctorConfigurationVersion {
                defaults.set(
                    Self.correctorConfigurationVersion,
                    forKey: "correctorConfigurationVersion"
                )
                defaults.set(Self.defaultCorrectorGroups, forKey: "correctorGroupNames")
                return Self.defaultCorrectorGroups
            }
            return defaults.stringArray(forKey: "correctorGroupNames")
                ?? Self.defaultCorrectorGroups
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "correctorGroupNames")
        }
    }

    var activePack: String {
        get {
            return UserDefaults.standard.string(forKey: "activePack") ?? "auto"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "activePack")
        }
    }

    var debugVerbose: Bool {
        get {
            return (
                UserDefaults.standard.object(forKey: "debugVerbose") as? Bool
            ) ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "debugVerbose")
        }
    }

    func ocrRuntimeSnapshot() -> OCRRuntimeSettingsSnapshot {
        OCRRuntimeSettingsSnapshot(
            confidenceThreshold: confidenceThreshold,
            multipassEnabled: multipassEnabled,
            roiUpscale: roiUpscale,
            correctorGroups: Set(
                correctorGroupNames.compactMap { CorrectorGroup(rawValue: $0) }
            ),
            activePack: activePack,
            improveEnabled: improveEnabled,
            debugVerbose: debugVerbose
        )
    }
}
