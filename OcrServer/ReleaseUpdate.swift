//
//  ReleaseUpdate.swift
//  OcrServer
//

import Combine
import Foundation
import UIKit

struct ReleaseManifest: Decodable, Sendable {
    let schema: Int
    let version: String
    let build: Int
    let gitSHA: String?
    let sha256: String
    let releaseNotes: String
    let ipaURL: URL
    let landingPageURL: URL

    enum CodingKeys: String, CodingKey {
        case schema
        case version
        case build
        case gitSHA = "git_sha"
        case sha256
        case releaseNotes = "release_notes"
        case ipaURL = "ipa_url"
        case landingPageURL = "landing_page_url"
    }
}

@MainActor
final class ReleaseUpdateModel: ObservableObject {
    private static let manifestURL = URL(
        string: "https://ipa.tuhomehanoi.site/latest.json"
    )!

    @Published private(set) var latest: ReleaseManifest?
    @Published private(set) var statusText = "Chua kiem tra ban moi"
    @Published private(set) var isChecking = false
    @Published private(set) var hasChecked = false

    var updateAvailable: Bool {
        guard let latest else { return false }
        return latest.build > BuildInfo.buildNumber
    }

    func check() async {
        guard !isChecking else { return }
        isChecking = true
        defer {
            isChecking = false
            hasChecked = true
        }

        do {
            var request = URLRequest(url: Self.manifestURL)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw UpdateError.invalidHTTPResponse
            }

            let manifest = try JSONDecoder().decode(ReleaseManifest.self, from: data)
            try validate(manifest)
            latest = manifest

            if manifest.build > BuildInfo.buildNumber {
                statusText = "Co ban moi \(manifest.version) (\(manifest.build))"
            } else if manifest.build == BuildInfo.buildNumber {
                statusText = "Dang dung ban moi nhat"
            } else {
                statusText = "Ban cai dat moi hon ban phat hanh"
            }
        } catch {
            latest = nil
            statusText = "Khong kiem tra duoc: \(error.localizedDescription)"
        }
    }

    func openUpdatePage() {
        guard updateAvailable, let url = latest?.landingPageURL else { return }
        UIApplication.shared.open(url)
    }

    private func validate(_ manifest: ReleaseManifest) throws {
        guard manifest.schema == 1,
              manifest.build > 0,
              !manifest.version.isEmpty,
              manifest.sha256.count == 64,
              manifest.sha256.allSatisfy({ $0.isHexDigit }),
              manifest.ipaURL.scheme == "https",
              manifest.landingPageURL.scheme == "https" else {
            throw UpdateError.invalidManifest
        }
    }
}

private enum UpdateError: LocalizedError {
    case invalidHTTPResponse
    case invalidManifest

    var errorDescription: String? {
        switch self {
        case .invalidHTTPResponse:
            return "may chu phat hanh khong tra ve HTTP thanh cong"
        case .invalidManifest:
            return "manifest phat hanh khong hop le"
        }
    }
}
