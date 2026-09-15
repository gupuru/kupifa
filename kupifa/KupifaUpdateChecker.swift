//
//  KupifaUpdateChecker.swift
//  kupifa
//
//  配布（GitHub Pages の version.json + GitHub Releases の DMG）向けの軽量アップデート通知。
//  起動時と設定の手動確認で version.json を取り、ローカル版より新しい場合だけ通知します。
//

import AppKit
import Foundation
import Combine
import SwiftUI

enum UpdateCheckStatus: Equatable {
    case idle
    case checking
    case upToDate
    case updateAvailable
    case failed
}

private struct RemoteVersionInfo: Decodable {
    let version: String
    let downloadUrl: String
}

@MainActor
final class KupifaUpdateChecker: ObservableObject {
    static let shared = KupifaUpdateChecker()

    @Published private(set) var status: UpdateCheckStatus = .idle
    @Published private(set) var updateAvailable: Bool = false
    @Published private(set) var localVersion: String
    @Published private(set) var remoteVersion: String?

    private let remoteInfoURL = URL(string: "https://gupuru.github.io/kupifa/version.json")!

    private init() {
        self.localVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func startChecking() {
        checkNow()
    }

    func checkNow() {
        Task { await checkForUpdates() }
    }

    func openDownloadPage() {
        guard let urlString = remoteDownloadUrl, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private var remoteDownloadUrl: String?
    private var checkGeneration = 0

    private func checkForUpdates() async {
        checkGeneration += 1
        let generation = checkGeneration
        status = .checking

        do {
            let info = try await fetchRemoteVersionInfo()
            guard generation == checkGeneration else { return }
            let isNewer = VersionSemver.isRemoteNewer(remote: info.version, local: localVersion)
            remoteVersion = info.version
            remoteDownloadUrl = info.downloadUrl
            updateAvailable = isNewer
            status = isNewer ? .updateAvailable : .upToDate
        } catch {
            guard generation == checkGeneration else { return }
            // 再確認の失敗で、すでに出している更新通知は消さない。
            if !updateAvailable {
                remoteVersion = nil
                remoteDownloadUrl = nil
            }
            status = .failed
        }
    }

    private func fetchRemoteVersionInfo() async throws -> RemoteVersionInfo {
        var components = URLComponents(url: remoteInfoURL, resolvingAgainstBaseURL: false)
        var items = components?.queryItems ?? []
        items.append(URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970))))
        components?.queryItems = items
        let url = components?.url ?? remoteInfoURL

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(RemoteVersionInfo.self, from: data)
    }
}

enum VersionSemver {
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

