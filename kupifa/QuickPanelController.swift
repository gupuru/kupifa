//
//  QuickPanelController.swift
//  kupifa
//
//  ホットキーで呼び出すSpotlight風フローティングパネル。
//

import AppKit
import SwiftUI

/// テキスト入力を受け付けられるボーダーレスパネル
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}

final class QuickPanelController {
    static let shared = QuickPanelController()

    private var panel: KeyablePanel?

    private init() {}

    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            showCapturingSelection()
        }
    }

    /// ホットキー用。他アプリのフォーカスを奪う前に選択テキストを取得してから開く。
    func showCapturingSelection() {
        SelectionCapture.capture { [weak self] text in
            self?.show(prefill: text)
        }
    }

    /// - Parameter append: true のとき、パネルが既に開いていれば入力欄の末尾へ追加する。
    func show(prefill: String? = nil, append: Bool = false) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let wasVisible = panel.isVisible
        AIService.warmConnections()

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = panel.frame.size
            // Spotlight風に画面中央よりやや上に表示
            let origin = NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2 + frame.height * 0.15
            )
            panel.setFrameOrigin(origin)
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.level = .floating
        panel.makeKeyAndOrderFront(nil)

        if let prefill, !prefill.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // パネル表示後に配信（HostingView の購読が生きている状態で届ける）
            let shouldAppend = append && wasVisible
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .kupifaPrefillInput,
                    object: prefill,
                    userInfo: [PrefillUserInfoKey.append: shouldAppend]
                )
            }
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    /// 設定を開く。フローティングパネルは閉じない。
    func presentSettings(_ openSettings: () -> Void) {
        keepVisibleForInternalWindows()
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

    /// 設定などアプリ内ウィンドウのあいだは、パネルを通常レベルにして重なりを整える。
    func keepVisibleForInternalWindows() {
        panel?.level = .normal
    }

    /// 設定ウィンドウが無くなったら、パネルを再び前面に浮かせる。
    func restoreFloatingLevelIfNeeded() {
        let otherTitled = NSApp.windows.contains { window in
            window.isVisible
                && !isPanelWindow(window)
                && window.styleMask.contains(.titled)
        }
        if !otherTitled {
            panel?.level = .floating
        }
    }

    func promoteFloatingLevel() {
        panel?.level = .floating
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func isPanelWindow(_ window: NSWindow) -> Bool {
        window === panel
    }

    private func makePanel() -> KeyablePanel {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 480),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        // 他アプリへフォーカスが移っても閉じない。閉じるのはボタン / Esc / ホットキーのみ。
        panel.hidesOnDeactivate = false
        // ウィンドウ自体は透明にし、SwiftUI側で描く角丸の不透明パネルを浮かせる
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let hosting = NSHostingView(rootView: QuickInputView(onClose: { [weak self] in
            self?.hide()
        }))
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.wantsLayer = true
        hosting.layer?.isOpaque = false
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hosting
        return panel
    }
}
