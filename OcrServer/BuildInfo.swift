//
//  BuildInfo.swift
//  OcrServer
//

import Foundation

enum BuildInfo {
    static var versionStamp: String {
        let info = Bundle.main.infoDictionary ?? [:]
        if let gitSHA = info["COMPUTE_BUILD_SHA"] as? String,
           !gitSHA.isEmpty,
           gitSHA != "$(COMPUTE_BUILD_SHA)" {
            return gitSHA
        }
        let version = (info["CFBundleShortVersionString"] as? String) ?? "Unknown"
        let build = (info["CFBundleVersion"] as? String) ?? "Unknown"
        return "\(version) (\(build))"
    }
}
