//
//  SelectionCapture.swift
//  kupifa
//
//  他アプリの選択テキストを取得する。
//  まず Accessibility の AXSelectedText を試し、取れなければ ⌘C を擬似送信してクリップボードから読む。
//

import AppKit
import ApplicationServices

enum SelectionCapture {
    /// パネルを出す前に呼ぶこと（フォーカスを奪う前に取得する）。
    static func capture(completion: @escaping (String?) -> Void) {
        if let text = selectedTextViaAccessibility(), !text.isEmpty {
            completion(text)
            return
        }

        guard isTrusted(prompt: true) else {
            // ダイアログを出したうえで、設定画面も開いて一覧に載りやすくする
            openAccessibilitySettings()
            completion(nil)
            return
        }

        captureViaCommandC(completion: completion)
    }

    // MARK: - Accessibility

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// 許可ダイアログを出し、必要ならシステム設定のアクセシビリティを開く。
    @discardableResult
    static func requestAccess(openSettingsIfDenied: Bool = true) -> Bool {
        let trusted = isTrusted(prompt: true)
        if !trusted, openSettingsIfDenied {
            openAccessibilitySettings()
        }
        return trusted
    }

    static func openAccessibilitySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private static func isTrusted(prompt: Bool) -> Bool {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    private static func selectedTextViaAccessibility() -> String? {
        guard isTrusted(prompt: false) else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success,
            let focusedRef
        else { return nil }

        let focused = focusedRef as! AXUIElement
        var selectedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &selectedRef
        ) == .success,
            let text = selectedRef as? String
        else { return nil }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : text
    }

    // MARK: - ⌘C フォールバック

    private static func captureViaCommandC(completion: @escaping (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        let changeCount = pasteboard.changeCount

        postCommandC()

        pollPasteboard(
            pasteboard: pasteboard,
            previousChangeCount: changeCount,
            snapshot: snapshot,
            attemptsLeft: 12,
            completion: completion
        )
    }

    private static func pollPasteboard(
        pasteboard: NSPasteboard,
        previousChangeCount: Int,
        snapshot: PasteboardSnapshot,
        attemptsLeft: Int,
        completion: @escaping (String?) -> Void
    ) {
        if pasteboard.changeCount != previousChangeCount {
            let text = pasteboard.string(forType: .string)
            snapshot.restore(to: pasteboard)
            let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            completion(trimmed.isEmpty ? nil : text)
            return
        }

        guard attemptsLeft > 0 else {
            snapshot.restore(to: pasteboard)
            completion(nil)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            pollPasteboard(
                pasteboard: pasteboard,
                previousChangeCount: previousChangeCount,
                snapshot: snapshot,
                attemptsLeft: attemptsLeft - 1,
                completion: completion
            )
        }
    }

    private static func postCommandC() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyC: CGKeyCode = 8 // kVK_ANSI_C

        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: false)
        else { return }

        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

// MARK: - クリップボード退避

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        var captured: [[NSPasteboard.PasteboardType: Data]] = []
        for item in pasteboard.pasteboardItems ?? [] {
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            if !dict.isEmpty {
                captured.append(dict)
            }
        }
        return PasteboardSnapshot(items: captured)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let objects: [NSPasteboardItem] = items.map { dict in
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(objects)
    }
}

extension Notification.Name {
    /// object に String（選択テキスト）を載せる
    static let kupifaPrefillInput = Notification.Name("kupifaPrefillInput")
}
