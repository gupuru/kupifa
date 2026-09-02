//
//  Models.swift
//  kupifa
//

import Foundation
import Carbon.HIToolbox

// MARK: - 処理モード

enum ActionMode: String, CaseIterable, Identifiable {
    case polish
    case reply
    case translate
    case speak
    case search

    var id: String { rawValue }

    /// パネル上部に表示するモード（検索は非表示）
    static var visibleCases: [ActionMode] {
        allCases.filter { $0 != .search }
    }

    var title: String {
        switch self {
        case .polish: "文章を整える"
        case .reply: "返事作成"
        case .translate: "翻訳"
        case .speak: "音声で読む"
        case .search: "検索"
        }
    }

    var icon: String {
        switch self {
        case .polish: "wand.and.stars"
        case .reply: "bubble.left.and.bubble.right"
        case .translate: "globe"
        case .speak: "speaker.wave.2"
        case .search: "magnifyingglass"
        }
    }

    /// ⌘1 / ⌘2 / ⌘3 / ⌘4 で切り替え（表示中のモードのみ）
    var shortcutKey: Character? {
        switch self {
        case .polish: "1"
        case .reply: "2"
        case .translate: "3"
        case .speak: "4"
        case .search: nil
        }
    }

    /// Web検索・音声読み上げは Grok のみ
    var requiresGrok: Bool {
        self == .search || self == .speak
    }
}

// MARK: - 音声読み上げのスタイル（Grok TTS）

enum SpeakStyle: String, CaseIterable, Identifiable {
    case plain
    case radio
    case summary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plain: "ただ読む"
        case .radio: "ラジオ風"
        case .summary: "要約版"
        }
    }
}

enum GrokVoice: String, CaseIterable, Identifiable {
    case eve
    case ara
    case rex
    case sal
    case leo

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - AIプロバイダ

enum AIProvider: String, CaseIterable, Identifiable {
    case grok

    var id: String { rawValue }
    var displayName: String { "Grok" }
    var defaultModel: String { "grok-4.6" }
    var fastModel: String { "grok-4.6" }

    /// カスタムモデルが無ければ、速さ優先設定に応じたデフォルトを返す
    func resolvedModel(preferSpeed: Bool) -> String {
        if let custom = UserDefaults.standard.string(forKey: modelDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        return preferSpeed ? fastModel : defaultModel
    }

    var modelDefaultsKey: String { "model.\(rawValue)" }
    var apiKeyHint: String { "https://console.x.ai" }
}

// MARK: - 出力言語

enum OutputLanguage: String, CaseIterable, Identifiable {
    case japanese
    case english

    var id: String { rawValue }

    var label: String {
        switch self {
        case .japanese: "日本語"
        case .english: "English"
        }
    }

    /// プロンプト内で使う言語名
    var promptName: String {
        switch self {
        case .japanese: "日本語"
        case .english: "英語"
        }
    }

    /// Grok TTS の language パラメータ
    var ttsLanguageCode: String {
        switch self {
        case .japanese: "ja"
        case .english: "en"
        }
    }

    var other: OutputLanguage {
        self == .japanese ? .english : .japanese
    }
}

// MARK: - グローバルホットキー

enum HotKeyOption: String, CaseIterable, Identifiable {
    case optionSpace
    case commandShiftSpace
    case controlSpace
    case commandSpace

    var id: String { rawValue }

    var label: String {
        switch self {
        case .optionSpace: "⌥ Space"
        case .commandShiftSpace: "⌘⇧ Space"
        case .controlSpace: "⌃ Space"
        case .commandSpace: "⌘ Space（Spotlightと競合注意）"
        }
    }

    var compactLabel: String {
        switch self {
        case .optionSpace: "⌥ Space"
        case .commandShiftSpace: "⌘⇧ Space"
        case .controlSpace: "⌃ Space"
        case .commandSpace: "⌘ Space"
        }
    }

    var keyCode: UInt32 { UInt32(kVK_Space) }

    var carbonModifiers: UInt32 {
        switch self {
        case .optionSpace: UInt32(optionKey)
        case .commandShiftSpace: UInt32(cmdKey | shiftKey)
        case .controlSpace: UInt32(controlKey)
        case .commandSpace: UInt32(cmdKey)
        }
    }

    static var current: HotKeyOption {
        UserDefaults.standard.string(forKey: SettingsKeys.hotKey)
            .flatMap(HotKeyOption.init(rawValue:)) ?? .optionSpace
    }
}

// MARK: - UserDefaultsキー

enum SettingsKeys {
    static let hotKey = "hotKeyOption"
    static let outputLanguage = "outputLanguage"
    static let generateBothLanguages = "generateBothLanguages"
    /// 速さ優先（速いモデル・短い出力上限）。未設定時は true
    static let preferSpeed = "preferSpeed"
    /// ⌘C 二連続でパネルを開く。未設定時は true
    static let openOnDoubleCopy = "openOnDoubleCopy"
    static let speakStyle = "speakStyle"
    static let grokVoice = "grokVoice"

    static var all: [String] {
        [
            hotKey,
            outputLanguage,
            generateBothLanguages,
            preferSpeed,
            openOnDoubleCopy,
            speakStyle,
            grokVoice,
        ]
    }
}
