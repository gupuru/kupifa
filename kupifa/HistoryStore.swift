//
//  HistoryStore.swift
//  kupifa
//
//  過去に実行した指示の履歴をUserDefaultsに保存する。
//

import Foundation

/// 履歴に保存する出力結果（プロバイダ × 言語ごと）
struct SavedResult: Codable, Equatable {
    let provider: String
    let language: String
    let text: String
}

struct HistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let mode: String
    let input: String
    /// 旧バージョンで保存した履歴には存在しないためオプショナル
    var results: [SavedResult]?

    init(mode: ActionMode, input: String) {
        self.id = UUID()
        self.date = Date()
        self.mode = mode.rawValue
        self.input = input
        self.results = nil
    }

    var actionMode: ActionMode {
        ActionMode(rawValue: mode) ?? .polish
    }

    var savedResults: [SavedResult] {
        results ?? []
    }
}

enum HistoryStore {
    static let key = "instructionHistory"
    private static let maxEntries = 50
    private static let saveQueue = DispatchQueue(label: "com.kupifa.history", qos: .utility)

    static func load() -> [HistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return [] }
        return entries
    }

    static func save(_ entries: [HistoryEntry]) {
        let trimmed = Array(entries.prefix(maxEntries))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// 完了パスをブロックしないよう、バックグラウンドで保存する
    static func saveAsync(_ entries: [HistoryEntry]) {
        let trimmed = Array(entries.prefix(maxEntries))
        saveQueue.async {
            if let data = try? JSONEncoder().encode(trimmed) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    /// 非同期保存の完了を待ってから消す（リセット直後の書き戻しを防ぐ）
    static func clear() {
        saveQueue.sync {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// 新しい履歴を先頭に追加して返す（直前と同一内容なら追加しない）
    static func appending(_ entry: HistoryEntry, to entries: [HistoryEntry]) -> [HistoryEntry] {
        if let latest = entries.first, latest.input == entry.input, latest.mode == entry.mode {
            return entries
        }
        return Array(([entry] + entries).prefix(maxEntries))
    }

    /// 指定した履歴エントリに出力結果を保存して返す（同じプロバイダ×言語は上書き）
    static func savingResult(
        _ text: String,
        provider: AIProvider,
        language: OutputLanguage,
        entryID: UUID,
        in entries: [HistoryEntry]
    ) -> [HistoryEntry] {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return entries }
        var entry = entries[index]
        var results = entry.savedResults
        let newResult = SavedResult(provider: provider.rawValue, language: language.rawValue, text: text)
        if let i = results.firstIndex(where: { $0.provider == newResult.provider && $0.language == newResult.language }) {
            results[i] = newResult
        } else {
            results.append(newResult)
        }
        entry.results = results
        var updated = entries
        updated[index] = entry
        return updated
    }
}
