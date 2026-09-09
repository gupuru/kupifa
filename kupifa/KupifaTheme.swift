//
//  KupifaTheme.swift
//  kupifa
//
//  LP（docs/）と同じトークン。クイックパネルの見た目をサイトに揃える。
//

import AppKit
import SwiftUI

enum KupifaTheme {
    static let bg = Color(red: 8 / 255, green: 9 / 255, blue: 12 / 255)
    static let bg2 = Color(red: 16 / 255, green: 18 / 255, blue: 24 / 255)
    static let surface = Color(red: 20 / 255, green: 22 / 255, blue: 28 / 255)
    static let ink = Color(red: 243 / 255, green: 239 / 255, blue: 228 / 255)
    static let muted = Color(red: 154 / 255, green: 149 / 255, blue: 136 / 255)
    static let lime = Color(red: 216 / 255, green: 255 / 255, blue: 62 / 255)
    static let limeDim = Color(red: 216 / 255, green: 255 / 255, blue: 62 / 255).opacity(0.14)
    static let line = Color(red: 243 / 255, green: 239 / 255, blue: 228 / 255).opacity(0.12)
    static let inkOnLime = Color(red: 17 / 255, green: 21 / 255, blue: 10 / 255)
    static let danger = Color(red: 255 / 255, green: 107 / 255, blue: 107 / 255)

    static let nsInk = NSColor(srgbRed: 243 / 255, green: 239 / 255, blue: 228 / 255, alpha: 1)
    static let nsMuted = NSColor(srgbRed: 154 / 255, green: 149 / 255, blue: 136 / 255, alpha: 1)
    static let nsLime = NSColor(srgbRed: 216 / 255, green: 255 / 255, blue: 62 / 255, alpha: 1)
    static let nsBg = NSColor(srgbRed: 8 / 255, green: 9 / 255, blue: 12 / 255, alpha: 1)

    static func applyWindowChrome(_ window: NSWindow) {
        window.backgroundColor = nsBg
    }
}
