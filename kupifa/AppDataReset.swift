//
//  AppDataReset.swift
//  kupifa
//
//  設定・履歴・APIキーを消し、初回起動と同じ状態に戻す。
//

import AppKit
import Foundation

enum AppDataReset {
    /// UserDefaults に残しているアプリ固有キー
    static var userDefaultsKeys: [String] {
        SettingsKeys.all + AIProvider.allCases.map(\.modelDefaultsKey) + [HistoryStore.key]
    }

    /// 配布先（/Applications）にあるときだけ本体をゴミ箱へ入れられる
    static var canMoveAppToTrash: Bool {
        Bundle.main.bundleURL.path.hasPrefix("/Applications/")
    }

    static func clearUserDefaults(_ defaults: UserDefaults) {
        for key in userDefaultsKeys {
            defaults.removeObject(forKey: key)
        }
    }

    /// キーチェーン・履歴・設定をすべて消す
    static func resetStoredData() {
        KeychainStore.deleteAllAPIKeys()
        HistoryStore.clear()
        clearUserDefaults(.standard)
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        UserDefaults.standard.synchronize()
    }

    @discardableResult
    static func moveAppToTrash() -> Bool {
        do {
            var resulting: NSURL?
            try FileManager.default.trashItem(at: Bundle.main.bundleURL, resultingItemURL: &resulting)
            return true
        } catch {
            return false
        }
    }

    @MainActor
    static func resetAndQuit() {
        resetStoredData()
        finishAndQuit()
    }

    @MainActor
    static func uninstallAndQuit() {
        resetStoredData()
        if canMoveAppToTrash {
            _ = moveAppToTrash()
        }
        finishAndQuit()
    }

    @MainActor
    private static func finishAndQuit() {
        QuickPanelController.shared.hide()
        NSApplication.shared.terminate(nil)
    }
}
