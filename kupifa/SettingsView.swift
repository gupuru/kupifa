//
//  SettingsView.swift
//  kupifa
//
//  APIキー・モデル・ホットキーなどの設定画面。
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            APIKeysSettingsTab()
                .tabItem { Label("APIキー", systemImage: "key.fill") }
            GeneralSettingsTab()
                .tabItem { Label("一般", systemImage: "gearshape") }
        }
        .frame(width: 520)
        .padding(.bottom, 8)
    }
}

// MARK: - APIキータブ

private struct APIKeysSettingsTab: View {
    var body: some View {
        Form {
            ForEach(AIProvider.allCases) { provider in
                Section {
                    ProviderKeyRow(provider: provider)
                }
            }
            Section {
                Text("APIキーはmacOSのキーチェーンに安全に保存されます。外部サーバーには送信されません（各AIプロバイダへのリクエストを除く）。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ProviderKeyRow: View {
    let provider: AIProvider

    @State private var apiKey = ""
    @State private var model = ""
    @State private var isSaved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(provider.displayName)
                    .font(.headline)
                if provider.supportsSearch {
                    Text("検索対応")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                }
                Spacer()
                if isSaved {
                    Label("保存済み", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            SecureField("APIキー（\(provider.apiKeyHint) で取得）", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)

            HStack {
                TextField("モデル名", text: $model, prompt: Text(provider.defaultModel))
                    .textFieldStyle(.roundedBorder)
                Button("保存", action: save)
                Button("削除", role: .destructive, action: clear)
                    .disabled(!isSaved)
            }

            Text("空欄時: 速さ優先 \(provider.fastModel) / 品質優先 \(provider.defaultModel)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .onAppear(perform: load)
    }

    private func load() {
        apiKey = KeychainStore.apiKey(for: provider) ?? ""
        isSaved = !apiKey.isEmpty
        model = UserDefaults.standard.string(forKey: provider.modelDefaultsKey) ?? ""
    }

    private func save() {
        KeychainStore.setAPIKey(apiKey, for: provider)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedModel.isEmpty {
            UserDefaults.standard.removeObject(forKey: provider.modelDefaultsKey)
        } else {
            UserDefaults.standard.set(trimmedModel, forKey: provider.modelDefaultsKey)
        }
        isSaved = !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func clear() {
        KeychainStore.deleteAPIKey(for: provider)
        apiKey = ""
        isSaved = false
    }
}

// MARK: - 一般タブ

private struct GeneralSettingsTab: View {
    @AppStorage(SettingsKeys.hotKey) private var hotKeyRaw = HotKeyOption.optionSpace.rawValue
    @AppStorage(SettingsKeys.defaultProvider) private var defaultProviderRaw = AIProvider.claude.rawValue
    @AppStorage(SettingsKeys.outputLanguage) private var outputLanguageRaw = OutputLanguage.japanese.rawValue
    @AppStorage(SettingsKeys.generateBothLanguages) private var generateBothLanguages = false
    @AppStorage(SettingsKeys.preferSpeed) private var preferSpeed = true
    @AppStorage(SettingsKeys.openOnDoubleCopy) private var openOnDoubleCopy = true
    @State private var accessibilityTrusted = SelectionCapture.isTrusted

    var body: some View {
        Form {
            Section("呼び出しホットキー") {
                Picker("ショートカット", selection: $hotKeyRaw) {
                    ForEach(HotKeyOption.allCases) { option in
                        Text(option.label).tag(option.rawValue)
                    }
                }
                .onChange(of: hotKeyRaw) { _, newValue in
                    if let option = HotKeyOption(rawValue: newValue) {
                        HotKeyManager.shared.register(option: option) {
                            QuickPanelController.shared.toggle()
                        }
                    }
                }
                Text("⌘ Space はSpotlightに割り当てられているため、使う場合はシステム設定でSpotlight側を無効化してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("選択テキストの取り込み") {
                HStack {
                    Label(
                        accessibilityTrusted ? "許可済み" : "未許可",
                        systemImage: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(accessibilityTrusted ? .green : .orange)
                    Spacer()
                    Button(accessibilityTrusted ? "設定を開く" : "許可する…") {
                        _ = SelectionCapture.requestAccess(openSettingsIfDenied: true)
                        // 許可ダイアログ／設定から戻ったあとに反映
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            accessibilityTrusted = SelectionCapture.isTrusted
                        }
                    }
                }
                Toggle("⌘C を2回連続でパネルを開く", isOn: $openOnDoubleCopy)
                    .onChange(of: openOnDoubleCopy) { _, enabled in
                        if enabled {
                            DoubleCopyMonitor.shared.start()
                        } else {
                            DoubleCopyMonitor.shared.stop()
                        }
                    }
                Text("他アプリで ⌘C をすばやく2回押すと、コピーしたテキストを入力欄に入れてパネルを開きます。ホットキー起動時も選択中のテキストを取り込みます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onAppear { accessibilityTrusted = SelectionCapture.isTrusted }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                accessibilityTrusted = SelectionCapture.isTrusted
            }

            Section("デフォルト") {
                Picker("AIプロバイダ", selection: $defaultProviderRaw) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }
                Picker("出力言語", selection: $outputLanguageRaw) {
                    ForEach(OutputLanguage.allCases) { lang in
                        Text(lang.label).tag(lang.rawValue)
                    }
                }
                .disabled(generateBothLanguages)
            }

            Section("速度") {
                Toggle("速さ優先", isOn: $preferSpeed)
                Text("ON: 高速モデル（Haiku / Grok 4.5・reasoning低）と短い出力上限。OFF: 品質寄りモデル。モデル名を手動指定している場合はそちらが優先されます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("生成") {
                Toggle("日本語と英語を同時に生成", isOn: $generateBothLanguages)
                Text("ONにすると、実行のたびに日本語と英語の両方の結果を生成します（翻訳モードでは無効）。リクエスト数は2倍になり、体感も遅くなります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
}
