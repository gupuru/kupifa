//
//  SettingsView.swift
//  kupifa
//
//  APIキー・モデル・ホットキーなどの設定画面。
//

import AppKit
import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case apiKeys
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apiKeys: "APIキー"
        case .general: "一般"
        }
    }
}

struct SettingsView: View {
    @State private var tab: SettingsTab = .apiKeys

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("kupifa")
                    .font(.subheadline.weight(.semibold))
                    .tracking(0.4)
                Text("設定")
                    .font(.caption)
                    .foregroundStyle(KupifaTheme.muted)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            HStack(spacing: 8) {
                ForEach(SettingsTab.allCases) { item in
                    Button {
                        tab = item
                    } label: {
                        Text(item.title)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(tab == item ? KupifaTheme.lime : KupifaTheme.muted)
                            .background {
                                Capsule()
                                    .fill(tab == item ? KupifaTheme.limeDim : Color.clear)
                                    .overlay {
                                        Capsule().strokeBorder(
                                            tab == item ? KupifaTheme.lime : Color.clear,
                                            lineWidth: 1
                                        )
                                    }
                            }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            KupifaTheme.line.frame(height: 1)

            ScrollView {
                Group {
                    switch tab {
                    case .apiKeys:
                        APIKeysSettingsTab()
                    case .general:
                        GeneralSettingsTab()
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 520, minHeight: 520)
        .foregroundStyle(KupifaTheme.ink)
        .background(KupifaTheme.bg)
        .preferredColorScheme(.dark)
        .background(SettingsFieldColorFix())
        .onAppear {
            NSApp.windows
                .filter { $0.isVisible && KupifaTheme.shouldApplyWindowChrome($0) }
                .forEach(KupifaTheme.applyWindowChrome)
        }
    }
}

// MARK: - 共通カード

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(KupifaTheme.lime)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(KupifaTheme.bg2)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(KupifaTheme.line, lineWidth: 1)
                }
        }
    }
}

private func settingsFieldBackground() -> some View {
    RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(KupifaTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(KupifaTheme.line, lineWidth: 1)
        }
}

/// システムのメニューは SwiftUI の tint だと項目名が黒くなる。
/// 閉じた状態の文字色は AppKit 側で明るい色に固定する。
private struct SettingsMenuField<Option: Identifiable & Hashable>: View {
    @Binding var selection: String
    let options: [Option]
    let optionID: (Option) -> String
    let optionTitle: (Option) -> String
    var isEnabled: Bool = true

    var body: some View {
        SettingsPopUpButton(
            items: options.map { (id: optionID($0), title: optionTitle($0)) },
            selection: $selection,
            isEnabled: isEnabled
        )
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
    }
}

private struct SettingsPopUpButton: NSViewRepresentable {
    var items: [(id: String, title: String)]
    @Binding var selection: String
    var isEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> CGSize? {
        let height = max(nsView.fittingSize.height, 28)
        let width = proposal.width ?? nsView.fittingSize.width
        return CGSize(width: width, height: height)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        button.appearance = NSAppearance(named: .darkAqua)
        button.target = context.coordinator
        button.action = #selector(Coordinator.changed(_:))
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.selection = $selection
        button.appearance = NSAppearance(named: .darkAqua)
        button.isEnabled = isEnabled
        button.contentTintColor = button.isEnabled ? KupifaTheme.nsInk : KupifaTheme.nsMuted

        let signature = items.map(\.id).joined(separator: "\u{1f}")
        if context.coordinator.itemsSignature != signature {
            context.coordinator.itemsSignature = signature
            button.removeAllItems()
            for item in items {
                button.addItem(withTitle: item.title)
                button.lastItem?.representedObject = item.id
            }
        }

        if let index = items.firstIndex(where: { $0.id == selection }), button.indexOfSelectedItem != index {
            button.selectItem(at: index)
        }
        applyTitleColor(button)
    }

    private func applyTitleColor(_ button: NSPopUpButton) {
        let title = button.selectedItem?.title ?? ""
        let color = button.isEnabled ? KupifaTheme.nsInk : KupifaTheme.nsMuted
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            ]
        )
    }

    final class Coordinator: NSObject {
        var selection: Binding<String>
        var itemsSignature = ""

        init(selection: Binding<String>) {
            self.selection = selection
        }

        @objc func changed(_ sender: NSPopUpButton) {
            guard let id = sender.selectedItem?.representedObject as? String else { return }
            selection.wrappedValue = id
            let color = sender.isEnabled ? KupifaTheme.nsInk : KupifaTheme.nsMuted
            sender.attributedTitle = NSAttributedString(
                string: sender.titleOfSelectedItem ?? "",
                attributes: [
                    .foregroundColor: color,
                    .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                ]
            )
        }
    }
}

/// プレーンな入力欄は、フォーカスが外れると文字色がシステムの黒に戻ることがある。
private struct SettingsFieldColorFix: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let root = nsView.window?.contentView else { return }
            recolorEditableFields(in: root)
        }
    }

    private func recolorEditableFields(in view: NSView) {
        if let field = view as? NSTextField, field.isEditable {
            field.textColor = KupifaTheme.nsInk
            if let editor = field.currentEditor() as? NSTextView {
                editor.insertionPointColor = KupifaTheme.nsInk
            }
        }
        for subview in view.subviews {
            recolorEditableFields(in: subview)
        }
    }
}

// MARK: - APIキータブ

private struct APIKeysSettingsTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(AIProvider.allCases) { provider in
                SettingsCard(title: provider.displayName) {
                    ProviderKeyRow(provider: provider)
                }
            }
            Text("APIキーはmacOSのキーチェーンに保存されます。外部サーバーには送信されません（Grok APIへのリクエストを除く）。")
                .font(.caption)
                .foregroundStyle(KupifaTheme.muted)
        }
    }
}

private struct ProviderKeyRow: View {
    let provider: AIProvider

    @State private var apiKey = ""
    @State private var model = ""
    @State private var isSaved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("検索・音声")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(KupifaTheme.lime)
                    .background {
                        Capsule()
                            .fill(KupifaTheme.limeDim)
                            .overlay {
                                Capsule().strokeBorder(KupifaTheme.lime.opacity(0.45), lineWidth: 1)
                            }
                    }
                Spacer()
                if isSaved {
                    Text("保存済み")
                        .font(.caption)
                        .foregroundStyle(KupifaTheme.lime)
                }
            }

            SecureField(
                "APIキー",
                text: $apiKey,
                prompt: Text("APIキー（\(provider.apiKeyHint) で取得）").foregroundStyle(KupifaTheme.muted)
            )
                .textFieldStyle(.plain)
                .foregroundStyle(KupifaTheme.ink)
                .padding(8)
                .background { settingsFieldBackground() }
                .onSubmit(save)

            HStack(spacing: 8) {
                TextField("モデル名", text: $model, prompt: Text(provider.defaultModel).foregroundStyle(KupifaTheme.muted))
                    .textFieldStyle(.plain)
                    .foregroundStyle(KupifaTheme.ink)
                    .padding(8)
                    .background { settingsFieldBackground() }
                Button("保存", action: save)
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(KupifaTheme.inkOnLime)
                    .background(Capsule().fill(KupifaTheme.lime))
                Button("削除", action: clear)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(isSaved ? KupifaTheme.danger : KupifaTheme.muted)
                    .disabled(!isSaved)
            }

            Text("空欄時: 速さ優先 \(provider.fastModel) / 品質優先 \(provider.defaultModel)")
                .font(.caption2)
                .foregroundStyle(KupifaTheme.muted)
        }
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
    @AppStorage(SettingsKeys.outputLanguage) private var outputLanguageRaw = OutputLanguage.japanese.rawValue
    @AppStorage(SettingsKeys.generateBothLanguages) private var generateBothLanguages = false
    @AppStorage(SettingsKeys.preferSpeed) private var preferSpeed = true
    @AppStorage(SettingsKeys.openOnDoubleCopy) private var openOnDoubleCopy = true
    @State private var accessibilityTrusted = SelectionCapture.isTrusted
    @StateObject private var updateChecker = KupifaUpdateChecker.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: "バージョン") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("現在 v\(updateChecker.localVersion)")
                        .font(.caption)
                        .foregroundStyle(KupifaTheme.muted)

                    versionStatusText

                    HStack(spacing: 8) {
                        Button {
                            updateChecker.checkNow()
                        } label: {
                            HStack(spacing: 6) {
                                if updateChecker.status == .checking {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(KupifaTheme.lime)
                                }
                                Text(updateChecker.status == .checking ? "確認中…" : "バージョンを確認")
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(KupifaTheme.lime)
                        .background {
                            Capsule()
                                .strokeBorder(KupifaTheme.lime, lineWidth: 1)
                        }
                        .disabled(updateChecker.status == .checking)

                        if updateChecker.updateAvailable, let remoteVersion = updateChecker.remoteVersion {
                            Button("ダウンロード（v\(remoteVersion)）") {
                                updateChecker.openDownloadPage()
                            }
                            .buttonStyle(.plain)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(KupifaTheme.inkOnLime)
                            .background(Capsule().fill(KupifaTheme.lime))
                        }
                    }
                }
            }

            SettingsCard(title: "呼び出しホットキー") {
                SettingsMenuField(
                    selection: $hotKeyRaw,
                    options: HotKeyOption.allCases,
                    optionID: \.rawValue,
                    optionTitle: \.label
                )
                .onChange(of: hotKeyRaw) { _, newValue in
                    if let option = HotKeyOption(rawValue: newValue) {
                        HotKeyManager.shared.register(option: option) {
                            QuickPanelController.shared.toggle()
                        }
                    }
                }
                Text("⌘ Space はSpotlightに割り当てられているため、使う場合はシステム設定でSpotlight側を無効化してください。")
                    .font(.caption)
                    .foregroundStyle(KupifaTheme.muted)
            }

            SettingsCard(title: "選択テキストの取り込み") {
                HStack {
                    Text(accessibilityTrusted ? "許可済み" : "未許可")
                        .font(.caption)
                        .foregroundStyle(accessibilityTrusted ? KupifaTheme.lime : Color.orange)
                    Spacer()
                    Button(accessibilityTrusted ? "設定を開く" : "許可する…") {
                        _ = SelectionCapture.requestAccess(openSettingsIfDenied: true)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            accessibilityTrusted = SelectionCapture.isTrusted
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(KupifaTheme.lime)
                    .background {
                        Capsule()
                            .strokeBorder(KupifaTheme.lime, lineWidth: 1)
                    }
                }
                Toggle(isOn: $openOnDoubleCopy) {
                    Text("⌘C を2回連続でパネルを開く")
                        .foregroundStyle(KupifaTheme.ink)
                }
                    .tint(KupifaTheme.lime)
                    .onChange(of: openOnDoubleCopy) { _, enabled in
                        if enabled {
                            DoubleCopyMonitor.shared.start()
                        } else {
                            DoubleCopyMonitor.shared.stop()
                        }
                    }
                Text("他アプリで ⌘C をすばやく2回押すと、コピーしたテキストを入力欄に入れてパネルを開きます。パネルが開いているときは末尾に追加します。ホットキー起動時も選択中のテキストを取り込みます。")
                    .font(.caption)
                    .foregroundStyle(KupifaTheme.muted)
            }
            .onAppear { accessibilityTrusted = SelectionCapture.isTrusted }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                accessibilityTrusted = SelectionCapture.isTrusted
            }

            SettingsCard(title: "デフォルト") {
                SettingsMenuField(
                    selection: $outputLanguageRaw,
                    options: OutputLanguage.allCases,
                    optionID: \.rawValue,
                    optionTitle: \.label,
                    isEnabled: !generateBothLanguages
                )
                Text("翻訳モードでは入力が日本語か英語かを文字から判定し、反対側へ訳します。")
                    .font(.caption)
                    .foregroundStyle(KupifaTheme.muted)
            }

            SettingsCard(title: "速度") {
                Toggle(isOn: $preferSpeed) {
                    Text("速さ優先")
                        .foregroundStyle(KupifaTheme.ink)
                }
                    .tint(KupifaTheme.lime)
                Text("ON: Grok 4.7（reasoning低）と短い出力上限。OFF: 品質寄り。モデル名を手動指定している場合はそちらが優先されます。")
                    .font(.caption)
                    .foregroundStyle(KupifaTheme.muted)
            }

            SettingsCard(title: "生成") {
                Toggle(isOn: $generateBothLanguages) {
                    Text("日本語と英語を同時に生成")
                        .foregroundStyle(KupifaTheme.ink)
                }
                    .tint(KupifaTheme.lime)
                Text("ONにすると、実行のたびに日本語と英語の両方の結果を生成します（翻訳モードでは無効）。リクエスト数は2倍になり、体感も遅くなります。")
                    .font(.caption)
                    .foregroundStyle(KupifaTheme.muted)
            }

            DataResetSection()
        }
    }

    @ViewBuilder
    private var versionStatusText: some View {
        switch updateChecker.status {
        case .idle:
            EmptyView()
        case .checking:
            Text("配布中の最新版を確認しています…")
                .font(.caption)
                .foregroundStyle(KupifaTheme.muted)
        case .upToDate:
            Text("最新です")
                .font(.caption)
                .foregroundStyle(KupifaTheme.lime)
        case .updateAvailable:
            Text("新しいバージョンがあります（v\(updateChecker.remoteVersion ?? "")）")
                .font(.caption)
                .foregroundStyle(KupifaTheme.lime)
        case .failed:
            Text("確認できませんでした。ネットワークを確認して再度お試しください。")
                .font(.caption)
                .foregroundStyle(KupifaTheme.danger)
        }
    }
}

// MARK: - データリセット / アンインストール

private struct DataResetSection: View {
    @State private var confirmReset = false
    @State private var confirmUninstall = false

    var body: some View {
        SettingsCard(title: "データ") {
            VStack(alignment: .leading, spacing: 12) {
                Button("すべてのデータをリセット…") {
                    confirmReset = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(KupifaTheme.danger)
                Text("APIキー、指示履歴、設定を削除して初回起動と同じ状態に戻し、アプリを終了します。アクセシビリティ許可はシステム設定に残ります。")
                    .font(.caption)
                    .foregroundStyle(KupifaTheme.muted)

                Button("アプリをアンインストール…") {
                    confirmUninstall = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(KupifaTheme.danger)
                Text(uninstallCaption)
                    .font(.caption)
                    .foregroundStyle(KupifaTheme.muted)
            }
        }
        .alert("すべてのデータをリセットしますか？", isPresented: $confirmReset) {
            Button("リセットして終了", role: .destructive) {
                AppDataReset.resetAndQuit()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("APIキー（キーチェーン）、指示履歴、ホットキーなどの設定をすべて削除します。この操作は取り消せません。")
        }
        .alert("kupifa をアンインストールしますか？", isPresented: $confirmUninstall) {
            Button("アンインストールして終了", role: .destructive) {
                AppDataReset.uninstallAndQuit()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(uninstallAlertMessage)
        }
    }

    private var uninstallCaption: String {
        if AppDataReset.canMoveAppToTrash {
            return "データをすべて削除し、アプリケーションフォルダの kupifa をゴミ箱へ移動して終了します。"
        }
        return "データをすべて削除して終了します。アプリ本体は、置いてある場所から手動でゴミ箱へ入れてください。"
    }

    private var uninstallAlertMessage: String {
        if AppDataReset.canMoveAppToTrash {
            return "APIキー、履歴、設定を削除し、kupifa をゴミ箱へ移動します。この操作は取り消せません。"
        }
        return "APIキー、履歴、設定を削除して終了します。アプリ本体は手動で削除してください。この操作は取り消せません。"
    }
}

#Preview {
    SettingsView()
}
