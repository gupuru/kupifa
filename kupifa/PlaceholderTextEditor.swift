//
//  PlaceholderTextEditor.swift
//  kupifa
//
//  IMEの未確定文字でもプレースホルダーが重ならない NSTextView。
//

import AppKit
import SwiftUI

struct PlaceholderTextEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isFocused: Bool
    var onHasContentChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true

        let textView = IMEAwareTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = KupifaTheme.nsInk
        textView.insertionPointColor = KupifaTheme.nsLime
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.textContainer?.lineFragmentPadding = 4
        textView.textContainer?.widthTracksTextView = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.placeholder = placeholder
        textView.onHasContentChange = onHasContentChange
        textView.string = text

        scroll.documentView = textView
        context.coordinator.textView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scroll.documentView as? IMEAwareTextView else { return }
        textView.placeholder = placeholder
        textView.onHasContentChange = onHasContentChange
        textView.textColor = KupifaTheme.nsInk
        textView.insertionPointColor = KupifaTheme.nsLime

        if !textView.hasMarkedText(), textView.string != text {
            textView.string = text
            textView.invalidatePlaceholder()
        }

        if isFocused, let window = scroll.window, window.firstResponder !== textView {
            window.makeFirstResponder(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlaceholderTextEditor
        weak var textView: IMEAwareTextView?

        init(_ parent: PlaceholderTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }
            parent.onHasContentChange(!textView.string.isEmpty || textView.hasMarkedText())
        }
    }
}

final class IMEAwareTextView: NSTextView {
    var placeholder = "" {
        didSet {
            if oldValue != placeholder { invalidatePlaceholder() }
        }
    }

    var onHasContentChange: ((Bool) -> Void)?

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        invalidatePlaceholder()
        notifyHasContent()
    }

    override func unmarkText() {
        super.unmarkText()
        invalidatePlaceholder()
        notifyHasContent()
    }

    override func didChangeText() {
        super.didChangeText()
        invalidatePlaceholder()
        notifyHasContent()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawPlaceholderIfNeeded()
    }

    func invalidatePlaceholder() {
        needsDisplay = true
    }

    private func notifyHasContent() {
        onHasContentChange?(!string.isEmpty || hasMarkedText())
    }

    private func drawPlaceholderIfNeeded() {
        guard string.isEmpty, !hasMarkedText(), !placeholder.isEmpty else { return }

        let padding = textContainer?.lineFragmentPadding ?? 0
        let origin = textContainerOrigin
        let width = max(0, (textContainer?.size.width ?? bounds.width) - padding * 2)
        let rect = NSRect(
            x: origin.x + padding,
            y: origin.y,
            width: width,
            height: bounds.height
        )
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? .systemFont(ofSize: 14),
            .foregroundColor: KupifaTheme.nsMuted,
        ]
        placeholder.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)
    }
}
