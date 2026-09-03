//
//  kupifaApp.swift
//  kupifa
//
//  メニューバー常駐型アプリ。ホットキーでクイック入力パネルを呼び出す。
//

import AppKit
import SwiftUI

@main
struct kupifaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarCommands()
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .accessibilityLabel("kupifa")
        }

        Settings {
            SettingsView()
        }
        .defaultSize(width: 540, height: 600)
    }
}

private struct MenuBarCommands: View {
    @Environment(\.openSettings) private var openSettings
    @StateObject private var updateChecker = KupifaUpdateChecker.shared

    var body: some View {
        Button("クイック入力を開く") {
            QuickPanelController.shared.show()
        }
        .keyboardShortcut("k")

        Divider()

        Button("設定…") {
            QuickPanelController.shared.presentSettings { openSettings() }
        }
        .keyboardShortcut(",")

        if updateChecker.updateAvailable, let remoteVersion = updateChecker.remoteVersion {
            Divider()
            Button("アップデート（v\(remoteVersion)）を入手") {
                updateChecker.openDownloadPage()
            }
        }

        Divider()

        Button("kupifa を終了") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        HotKeyManager.shared.register(option: .current) {
            QuickPanelController.shared.toggle()
        }
        DoubleCopyMonitor.shared.start()
        AIService.warmConnections()
        KupifaUpdateChecker.shared.startChecking()

        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            if QuickPanelController.shared.isPanelWindow(window) {
                QuickPanelController.shared.promoteFloatingLevel()
                return
            }
            KupifaTheme.applyWindowChrome(window)
            if window.styleMask.contains(.titled) {
                QuickPanelController.shared.keepVisibleForInternalWindows()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow,
                  !QuickPanelController.shared.isPanelWindow(window)
            else { return }
            DispatchQueue.main.async {
                QuickPanelController.shared.restoreHidesOnDeactivateIfNeeded()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
        DoubleCopyMonitor.shared.stop()
    }
}
