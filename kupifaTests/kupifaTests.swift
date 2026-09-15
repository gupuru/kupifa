//
//  kupifaTests.swift
//  kupifaTests
//

import Testing
import Foundation
@testable import kupifa

struct DroppedTextLoaderTests {
    @Test func supportsHtmlAndMarkdown() {
        #expect(DroppedTextLoader.isSupported(url: URL(fileURLWithPath: "/tmp/note.md")))
        #expect(DroppedTextLoader.isSupported(url: URL(fileURLWithPath: "/tmp/page.HTML")))
        #expect(DroppedTextLoader.isSupported(url: URL(fileURLWithPath: "/tmp/readme.markdown")))
        #expect(DroppedTextLoader.isSupported(url: URL(fileURLWithPath: "/tmp/memo.txt")))
        #expect(!DroppedTextLoader.isSupported(url: URL(fileURLWithPath: "/tmp/photo.png")))
        #expect(!DroppedTextLoader.isSupported(url: URL(fileURLWithPath: "/tmp/deck.pdf")))
    }

    @Test func extractsVisibleTextFromHTML() {
        let html = """
        <html><head><title>Ignore</title><script>alert(1)</script></head>
        <body>
          <h1>見出し</h1>
          <p>こんにちは&nbsp;<b>世界</b>。</p>
          <p>次の段&#x26;続き</p>
        </body></html>
        """
        let text = DroppedTextLoader.htmlToPlainText(html)
        #expect(text.contains("見出し"))
        #expect(text.contains("こんにちは"))
        #expect(text.contains("世界"))
        #expect(text.contains("次の段&続き"))
        #expect(!text.contains("alert"))
        #expect(!text.contains("<p>"))
    }

    @Test func decodesCommonEntities() {
        let decoded = DroppedTextLoader.decodeHTMLEntities("A&amp;B &#39;quote&#39; &#123; {")
        #expect(decoded.contains("A&B"))
        #expect(decoded.contains("'quote'"))
    }

    @Test func loadsMarkdownFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kupifa-test.md")
        try "# 題名\n\n本文です。".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let text = try DroppedTextLoader.load(from: url)
        #expect(text.contains("題名"))
        #expect(text.contains("本文です。"))
    }
}

struct TextChunkerTests {
    @Test func keepsShortTextAsOneChunk() {
        #expect(TextChunker.split("短い文章です。") == ["短い文章です。"])
    }

    @Test func splitsLongTextNearLimit() {
        let paragraph = String(repeating: "あ。", count: 4000)
        let chunks = TextChunker.split(paragraph, maxLength: 100)
        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { $0.count <= 100 })
        #expect(chunks.joined().contains("あ"))
    }
}

struct AppDataResetTests {
    @Test func knownKeysCoverSettingsHistoryAndModels() {
        let keys = Set(AppDataReset.userDefaultsKeys)
        for key in SettingsKeys.all {
            #expect(keys.contains(key))
        }
        #expect(keys.contains(HistoryStore.key))
        #expect(keys.contains("model.grok"))
    }

    @Test func clearUserDefaultsRemovesKnownKeys() {
        let suite = "com.kupifa.reset-test"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("UserDefaults suite を作れませんでした")
            return
        }
        defaults.removePersistentDomain(forName: suite)

        defaults.set("commandSpace", forKey: SettingsKeys.hotKey)
        defaults.set(false, forKey: SettingsKeys.preferSpeed)
        defaults.set("custom-model", forKey: "model.grok")
        defaults.set(Data("history".utf8), forKey: HistoryStore.key)

        AppDataReset.clearUserDefaults(defaults)

        #expect(defaults.string(forKey: SettingsKeys.hotKey) == nil)
        #expect(defaults.object(forKey: SettingsKeys.preferSpeed) == nil)
        #expect(defaults.string(forKey: "model.grok") == nil)
        #expect(defaults.data(forKey: HistoryStore.key) == nil)

        defaults.removePersistentDomain(forName: suite)
    }
}

struct LanguageDetectorTests {
    @Test func japaneseGoesToEnglish() {
        #expect(LanguageDetector.detectSource("明日の打ち合わせ、少し遅れそうです。") == .japanese)
        #expect(LanguageDetector.translationTarget(for: "明日の打ち合わせ、少し遅れそうです。") == .english)
        #expect(LanguageDetector.detectSource("カタカナだけの文") == .japanese)
        #expect(LanguageDetector.detectSource("了解") == .japanese)
        #expect(LanguageDetector.translationTarget(for: "了解") == .english)
    }

    @Test func englishGoesToJapanese() {
        #expect(LanguageDetector.detectSource("Please find the attached deck for tomorrow's review.") == .english)
        #expect(LanguageDetector.translationTarget(for: "Please find the attached deck for tomorrow's review.") == .japanese)
        #expect(LanguageDetector.detectSource("OK") == .english)
        #expect(LanguageDetector.translationTarget(for: "OK") == .japanese)
    }

    @Test func mixedJapaneseWithEnglishWordsStaysJapanese() {
        let text = "明日の meeting について確認です。"
        #expect(LanguageDetector.detectSource(text) == .japanese)
        #expect(LanguageDetector.translationTarget(for: text) == .english)
    }

    @Test func emptyOrSymbolsDefaultToEnglishSource() {
        #expect(LanguageDetector.detectSource("") == .english)
        #expect(LanguageDetector.detectSource("12345") == .english)
        #expect(LanguageDetector.translationTarget(for: "12345") == .japanese)
    }
}

struct VersionSemverTests {
    @Test func equalVersionsAreNotNewer() {
        #expect(!VersionSemver.isRemoteNewer(remote: "1.0", local: "1.0"))
        #expect(!VersionSemver.isRemoteNewer(remote: "1.0.0", local: "1.0"))
        #expect(!VersionSemver.isRemoteNewer(remote: "1.0", local: "1.0.0"))
    }

    @Test func remotePatchOrMinorIsNewer() {
        #expect(VersionSemver.isRemoteNewer(remote: "1.0.1", local: "1.0"))
        #expect(VersionSemver.isRemoteNewer(remote: "1.1", local: "1.0"))
        #expect(VersionSemver.isRemoteNewer(remote: "2.0", local: "1.9.9"))
    }

    @Test func olderRemoteIsNotNewer() {
        #expect(!VersionSemver.isRemoteNewer(remote: "1.0", local: "1.1"))
        #expect(!VersionSemver.isRemoteNewer(remote: "0.9", local: "1.0"))
    }
}

struct SpeakModeTests {
    @Test func speakIsVisibleAndGrokOnly() {
        #expect(ActionMode.visibleCases.contains(.speak))
        #expect(ActionMode.speak.requiresGrok)
        #expect(ActionMode.speak.shortcutKey == "4")
        #expect(AIProvider.allCases == [.grok])
    }

    @Test func radioPromptAsksForSpokenScript() {
        let prompt = PromptBuilder.build(
            mode: .speak,
            input: "記事本文",
            outputLanguage: .japanese,
            speakStyle: .radio
        )
        #expect(prompt.system.contains("ラジオ"))
        #expect(prompt.system.contains("日本語"))
        #expect(prompt.user == "記事本文")
    }

    @Test func summaryPromptAsksForShortNarration() {
        let prompt = PromptBuilder.build(
            mode: .speak,
            input: "長い記事",
            outputLanguage: .english,
            speakStyle: .summary
        )
        #expect(prompt.system.contains("要約") || prompt.system.contains("要点"))
        #expect(prompt.system.contains("英語"))
    }
}
