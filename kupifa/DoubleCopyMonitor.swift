//
//  DoubleCopyMonitor.swift
//  kupifa
//
//  他アプリで ⌘C を短時間に2回押したら、クリップボードの内容でパネルを開く。
//  パネルが既に開いていれば、入力欄の末尾へ追加する。
//

import AppKit
import Carbon.HIToolbox

final class DoubleCopyMonitor {
    static let shared = DoubleCopyMonitor()

    /// 2回目と判定する間隔（秒）
    private let doubleInterval: TimeInterval = 0.45
    /// 2回目のコピーがペーストボードに反映されるまでの待ち
    private let pasteboardSettle: TimeInterval = 0.08

    private var monitor: Any?
    private var lastCopyAt: Date?
    private var openWorkItem: DispatchWorkItem?

    private init() {}

    var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: SettingsKeys.openOnDoubleCopy) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: SettingsKeys.openOnDoubleCopy)
    }

    func start() {
        stop()
        guard isEnabled else { return }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        openWorkItem?.cancel()
        openWorkItem = nil
        lastCopyAt = nil
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard !event.isARepeat,
              event.keyCode == UInt16(kVK_ANSI_C),
              isCommandC(event)
        else { return }

        let now = Date()
        if let lastCopyAt, now.timeIntervalSince(lastCopyAt) <= doubleInterval {
            self.lastCopyAt = nil
            scheduleOpenFromPasteboard()
        } else {
            lastCopyAt = now
        }
    }

    private func isCommandC(_ event: NSEvent) -> Bool {
        var flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        flags.remove(.capsLock)
        flags.remove(.numericPad)
        flags.remove(.function)
        return flags == .command
    }

    private func scheduleOpenFromPasteboard() {
        openWorkItem?.cancel()
        let work = DispatchWorkItem {
            let text = NSPasteboard.general.string(forType: .string)
            let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else { return }
            QuickPanelController.shared.show(prefill: text, append: true)
        }
        openWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteboardSettle, execute: work)
    }
}
