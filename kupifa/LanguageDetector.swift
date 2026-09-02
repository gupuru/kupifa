//
//  LanguageDetector.swift
//  kupifa
//
//  日本語と英語を文字種から判定する（AIは使わない）。
//

import Foundation

enum LanguageDetector {
    /// 入力が日本語寄りか英語寄りかを返す。
    /// ひらがな・カタカナがあれば日本語。それ以外は漢字とラテン文字の多い方。
    static func detectSource(_ text: String) -> OutputLanguage {
        var japanese = 0
        var latin = 0
        var hasKana = false

        for scalar in text.unicodeScalars {
            if isKana(scalar) {
                hasKana = true
                japanese += 1
            } else if isKanji(scalar) {
                japanese += 1
            } else if isLatinLetter(scalar) {
                latin += 1
            }
        }

        if hasKana {
            return .japanese
        }
        if japanese == 0 && latin == 0 {
            return .english
        }
        return japanese > latin ? .japanese : .english
    }

    /// 翻訳先。日本語なら英語、英語なら日本語。
    static func translationTarget(for text: String) -> OutputLanguage {
        detectSource(text).other
    }

    private static func isKana(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x309F: true // ひらがな
        case 0x30A0...0x30FF: true // カタカナ
        case 0x31F0...0x31FF: true // カタカナ拡張
        case 0xFF66...0xFF9D: true // 半角カタカナ
        default: false
        }
    }

    private static func isKanji(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF: true // CJK拡張A
        case 0x4E00...0x9FFF: true // CJK統合漢字
        default: false
        }
    }

    private static func isLatinLetter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x41...0x5A, 0x61...0x7A: true // A–Z a–z
        case 0xC0...0xD6, 0xD8...0xF6, 0xF8...0xFF: true // Latin-1 字母
        case 0xFF21...0xFF3A, 0xFF41...0xFF5A: true // 全角英字
        default: false
        }
    }
}
