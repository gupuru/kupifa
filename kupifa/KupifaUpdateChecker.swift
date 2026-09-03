//
//  KupifaUpdateChecker.swift
//  kupifa
//
//  配布（Cloudflare Pages + DMG）向けの軽量アップデート通知。
//  app 起動時に version.json を取得して、ローカル版より新しい場合だけ UI に出します。
//

import AppKit
import Foundation
import Combine
import SwiftUI

private struct RemoteVersionInfo: Decodable {
    let version: String
    let downloadUrl: String
}

@MainActor
final class KupifaUpdateChecker: ObservableObject {
    static let shared = KupifaUpdateChecker()

    @Published private(set) var updateAvailable: Bool = false
    @Published private(set) var localVersion: String
    @Published private(set) var remoteVersion: String?

    private let remoteInfoURL = URL(string: "https://kupifa.pages.dev/version.json")!

    private init() {
        self.localVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func startChecking() {
        Task { await checkForUpdates() }
    }

    func openDownloadPage() {
        guard let urlString = remoteDownloadUrl, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private var remoteDownloadUrl: String?

    private func checkForUpdates() async {
        do {
            let info = try await fetchRemoteVersionInfo()
            let isNewer = VersionSemver.isRemoteNewer(remote: info.version, local: localVersion)
            updateAvailable = isNewer
            remoteVersion = isNewer ? info.version : nil
            remoteDownloadUrl = info.downloadUrl
        } catch {
            // アップデート確認は補助機能なので、失敗時は黙って無効化します。
            updateAvailable = false
            remoteVersion = nil
            remoteDownloadUrl = nil
        }
    }

    private func fetchRemoteVersionInfo() async throws -> RemoteVersionInfo {
        var request = URLRequest(url: remoteInfoURL)
        request.timeoutInterval = 2.5
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(RemoteVersionInfo.self, from: data)
    }
}

private enum VersionSemver {
    // "1.0", "1.0.0" などを想定した簡易比較（数値部分のみ）。
    static func isRemoteNewer(remote: String, local: String) -> Bool {
        let remoteParts = parse(remote)
        let localParts = parse(local)

        let maxCount = max(remoteParts.count, localParts.count)
        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r != l { return r > l }
        }
        return false
    }

    private static func parse(_ version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }
}

