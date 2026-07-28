//
//  kupifaApp.swift
//  kupifa
//
//  メニューバー常駐型アプリ。ホットキーでクイック入力パネルを呼び出す。
//

import SwiftUI

@main
struct kupifaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("kupifa", systemImage: "sparkles") {
            Button("クイック入力を開く") {
                QuickPanelController.shared.show()
            }
            .keyboardShortcut("k")

            Divider()

            SettingsLink {
                Text("設定…")
            }
            .keyboardShortcut(",")

            Divider()

            Button("kupifa を終了") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        HotKeyManager.shared.register(option: .current) {
            QuickPanelController.shared.toggle()
        }
        DoubleCopyMonitor.shared.start()
        // APIホストへのTLSを先に張っておく（初回リクエストの接続待ちを短縮）
        AIService.warmConnections()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
        DoubleCopyMonitor.shared.stop()
    }
}
