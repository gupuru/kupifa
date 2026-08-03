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
        case .search: "検索"
        }
    }

    var icon: String {
        switch self {
        case .polish: "wand.and.stars"
        case .reply: "bubble.left.and.bubble.right"
        case .translate: "globe"
        case .search: "magnifyingglass"
        }
    }

    /// ⌘1 / ⌘2 / ⌘3 で切り替え（表示中のモードのみ）
    var shortcutKey: Character? {
        switch self {
        case .polish: "1"
        case .reply: "2"
        case .translate: "3"
        case .search: nil
        }
    }
}

// MARK: - AIプロバイダ

enum AIProvider: String, CaseIterable, Identifiable {
    case grok
    case claude

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grok: "Grok"
        case .claude: "Claude"
        }
    }

    /// 品質優先時のデフォルトモデル
    var defaultModel: String {
        switch self {
        case .grok: "grok-4.5"
        case .claude: "claude-sonnet-4-5"
        }
    }

    /// 速さ優先時のデフォルトモデル
    var fastModel: String {
        switch self {
        case .grok: "grok-4.5"
        case .claude: "claude-haiku-4-5"
        }
    }

    /// カスタムモデルが無ければ、速さ優先設定に応じたデフォルトを返す
    func resolvedModel(preferSpeed: Bool) -> String {
        if let custom = UserDefaults.standard.string(forKey: modelDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        return preferSpeed ? fastModel : defaultModel
    }

    /// Web検索モードに対応しているのはGrokのみ
    var supportsSearch: Bool { self == .grok }

    var modelDefaultsKey: String { "model.\(rawValue)" }

    /// 設定画面に表示するAPIキー取得先
    var apiKeyHint: String {
        switch self {
        case .grok: "https://console.x.ai"
        case .claude: "https://console.anthropic.com"
        }
    }
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
    static let defaultProvider = "defaultProvider"
    static let outputLanguage = "outputLanguage"
    static let generateBothLanguages = "generateBothLanguages"
    /// 速さ優先（速いモデル・短い出力上限）。未設定時は true
    static let preferSpeed = "preferSpeed"
    /// ⌘C 二連続でパネルを開く。未設定時は true
    static let openOnDoubleCopy = "openOnDoubleCopy"
}
