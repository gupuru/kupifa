//
//  QuickInputView.swift
//  kupifa
//
//  ホットキーで表示されるメインのフォーム画面。
//  LPと同じダーク＋ライムの不透明パネル。
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - 実行結果（プロバイダごと）

struct ModelRun: Identifiable {
    enum RunState {
        /// status: 接続中… / 応答待ち… / 考え中… など
        case loading(status: String)
        case streaming(String)
        case success(String)
        case failure(String)

        var isInProgress: Bool {
            switch self {
            case .loading, .streaming: true
            case .success, .failure: false
            }
        }

        var text: String? {
            switch self {
            case .streaming(let text), .success(let text): text
            case .loading, .failure: nil
            }
        }

        var loadingStatus: String? {
            if case .loading(let status) = self { return status }
            return nil
        }
    }

    let provider: AIProvider
    /// カードのスイッチで現在表示している言語
    var displayLanguage: OutputLanguage
    /// 言語ごとの生成状態（未生成の言語はキーなし）
    var states: [OutputLanguage: RunState]

    var id: String { provider.rawValue }

    var currentState: RunState {
        states[displayLanguage] ?? .loading(status: "接続中…")
    }

    var resultText: String? {
        guard let text = currentState.text, !text.isEmpty else { return nil }
        return text
    }
}

struct QuickInputView: View {
    var onClose: () -> Void

    @State private var mode: ActionMode = .polish
    @State private var inputText = ""
    /// IME変換中の未確定文字も含めて、入力欄に何か表示されているか
    @State private var editorHasText = false
    @State private var runs: [ModelRun] = []
    @State private var copiedProviderID: String?
    @State private var runningTasks: [Task<Void, Never>] = []
    /// カードの言語スイッチで未生成言語を翻訳するために、直近の実行内容を保持
    @State private var lastInput = ""
    @State private var lastMode: ActionMode = .polish
    /// 出力結果の保存先となる履歴エントリ
    @State private var currentHistoryID: UUID?
    @State private var history: [HistoryEntry] = HistoryStore.load()
    @State private var showHistory = true
    @State private var isDropTargeted = false
    @State private var dropMessage: String?
    @State private var speechError: String?
    @State private var isSynthesizingSpeech = false
    @State private var speechGeneration = UUID()
    @StateObject private var speechPlayer = SpeechPlayer()

    @AppStorage(SettingsKeys.outputLanguage) private var outputLanguageRaw = OutputLanguage.japanese.rawValue
    @AppStorage(SettingsKeys.generateBothLanguages) private var generateBothLanguages = false
    @AppStorage(SettingsKeys.preferSpeed) private var preferSpeed = true
    @AppStorage(SettingsKeys.speakStyle) private var speakStyleRaw = SpeakStyle.plain.rawValue
    @AppStorage(SettingsKeys.grokVoice) private var grokVoiceRaw = GrokVoice.eve.rawValue

    @FocusState private var inputFocused: Bool
    @Environment(\.openSettings) private var openSettings

    private var outputLanguage: OutputLanguage {
        OutputLanguage(rawValue: outputLanguageRaw) ?? .japanese
    }

    private var isLoading: Bool {
        isSynthesizingSpeech || runs.contains { run in
            run.states.values.contains { $0.isInProgress }
        }
    }

    /// 履歴サイドバーと結果カラムの数に応じてパネルを横に広げる
    private var panelMinWidth: CGFloat {
        let base: CGFloat = showHistory ? 800 : 620
        return runs.isEmpty ? base : base + CGFloat(runs.count) * 160
    }

    var body: some View {
        VStack(spacing: 0) {
            chrome
            header
            KupifaTheme.line.frame(height: 1)
            content
        }
        .frame(minWidth: panelMinWidth, minHeight: 440)
        .foregroundStyle(KupifaTheme.ink)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear { inputFocused = true }
        .onDisappear {
            cancelRunningTasks()
            speechPlayer.reset()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kupifaPrefillInput)) { note in
            guard let text = note.object as? String,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return }
            applyPrefill(text)
        }
        .background { hiddenShortcuts }
    }

    // MARK: - 背景（LPと同じダーク）

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(KupifaTheme.bg)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(KupifaTheme.line, lineWidth: 1)
            }
    }

    /// 入力欄・履歴の面
    private func innerSurface(cornerRadius: CGFloat = 12, highlighted: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(KupifaTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(highlighted ? KupifaTheme.lime.opacity(0.35) : KupifaTheme.line, lineWidth: 1)
            }
    }

    private func pillBackground(selected: Bool) -> some View {
        Capsule()
            .fill(selected ? KupifaTheme.limeDim : Color.clear)
            .overlay {
                Capsule().strokeBorder(
                    selected ? KupifaTheme.lime : Color.clear,
                    lineWidth: 1
                )
            }
    }

    // MARK: - クローム

    private var chrome: some View {
        HStack(spacing: 10) {
            Text("kupifa")
                .font(.subheadline.weight(.semibold))
                .tracking(0.4)
            Spacer()
            Text("Grok · \(HotKeyOption.current.compactLabel)")
                .font(.caption)
                .foregroundStyle(KupifaTheme.muted)
            Button(action: onClose) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                    Text("閉じる")
                }
                .font(.caption)
                .foregroundStyle(KupifaTheme.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    Capsule()
                        .strokeBorder(KupifaTheme.line, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .help("パネルを閉じる（Esc）")
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - ヘッダー（モード切替・実行対象）

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                showHistory.toggle()
            } label: {
                Image(systemName: "sidebar.left")
                    .foregroundStyle(showHistory ? KupifaTheme.lime : KupifaTheme.muted)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("0", modifiers: .command)
            .help("履歴の表示/非表示（⌘0）")

            ForEach(ActionMode.visibleCases) { m in
                Button {
                    switchMode(to: m)
                } label: {
                    Text(m.title)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(mode == m ? KupifaTheme.lime : KupifaTheme.muted)
                        .background { pillBackground(selected: mode == m) }
                }
                .buttonStyle(.plain)
                .modifier(ModeShortcutModifier(key: m.shortcutKey))
                .help(m.shortcutKey.map { "⌘\($0) で切り替え" } ?? m.title)
            }

            Spacer()

            Button {
                preferSpeed.toggle()
            } label: {
                Text("速さ優先")
                    .font(.caption)
                    .foregroundStyle(preferSpeed ? KupifaTheme.lime : KupifaTheme.muted)
            }
            .buttonStyle(.plain)
            .help("高速モデルと短い出力上限を使う（⌘F）")

            Button {
                QuickPanelController.shared.presentSettings { openSettings() }
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(KupifaTheme.muted)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .help("設定を開く（⌘,）")
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    /// 見た目を持たないショートカット専用ボタン群
    private var hiddenShortcuts: some View {
        Group {
            Button("", action: { preferSpeed.toggle() })
                .keyboardShortcut("f", modifiers: .command)
            Button("", action: clearAll)
                .keyboardShortcut("k", modifiers: .command)
            Button("", action: copyFirstResult)
                .keyboardShortcut("c", modifiers: [.command, .shift])
            Button("", action: toggleOutputLanguage)
                .keyboardShortcut("l", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    // MARK: - 本体

    private var inputEditor: some View {
        PlaceholderTextEditor(
            text: $inputText,
            placeholder: placeholder,
            isFocused: inputFocused,
            onHasContentChange: { editorHasText = $0 }
        )
        .focused($inputFocused)
        .padding(8)
        .frame(minHeight: 90)
        .background(innerSurface())
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(KupifaTheme.lime, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(KupifaTheme.limeDim)
                    }
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "doc.text")
                            Text("HTML / Markdown をドロップ")
                                .font(.caption)
                        }
                        .foregroundStyle(KupifaTheme.muted)
                    }
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            // 履歴サイドバー（一番左）
            if showHistory {
                historySidebar
                    .frame(width: 180)

                KupifaTheme.line.frame(width: 1)
            }

            inputColumn
                .frame(minWidth: 280)
                .frame(maxWidth: runs.isEmpty ? .infinity : 340)

            // 結果は入力欄の右横に、モデルごとの縦カラムで並べる
            if !runs.isEmpty {
                KupifaTheme.line.frame(width: 1)

                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(runs.enumerated()), id: \.element.id) { index, run in
                        resultCard(run: run, index: index)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
        .onChange(of: inputText) { _, newValue in
            adoptDroppedFilePathIfNeeded(newValue)
        }
    }

    private var inputColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            if mode == .speak {
                speakStylePicker
            } else if mode == .translate {
                translateDirectionHint
            }

            inputEditor

            if let dropMessage {
                Text(dropMessage)
                    .font(.caption)
                    .foregroundStyle(dropMessage.contains("読み込み") ? KupifaTheme.muted : Color.orange)
            } else {
                Text("テキストの貼り付け、または HTML / Markdown ファイルのドロップ")
                    .font(.caption2)
                    .foregroundStyle(KupifaTheme.muted)
            }

            HStack {
                Button {
                    run()
                } label: {
                    if isLoading {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small).tint(KupifaTheme.inkOnLime)
                            Text(mode == .speak ? "読み上げ中…" : "生成中…")
                        }
                    } else {
                        Text(mode == .speak ? "読み上げ ⌘⏎" : "実行 ⌘⏎")
                    }
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(KupifaTheme.inkOnLime)
                .background(Capsule().fill(KupifaTheme.lime))
                .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help(isLoading ? "再実行すると進行中の生成をキャンセルします" : "⌘⏎ で実行")

                Button {
                    clearAll()
                } label: {
                    Text("新規")
                        .font(.caption)
                        .foregroundStyle(KupifaTheme.muted)
                }
                .buttonStyle(.plain)
                .help("入力と結果をクリアして新規作成（⌘K）")
                .disabled(inputText.isEmpty && runs.isEmpty && !editorHasText)

                Spacer()
            }

            Text("⌘⏎ 実行 ・ ⌘K 新規 ・ ⌘F 速さ ・ ⌘L 言語 ・ Esc 閉じる")
                .font(.caption)
                .foregroundStyle(KupifaTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .help("⌘1 整える ・ ⌘2 返事作成 ・ ⌘3 翻訳 ・ ⌘4 音声")
        }
    }

    private var speakStylePicker: some View {
        HStack(spacing: 6) {
            ForEach(SpeakStyle.allCases) { style in
                Button {
                    speakStyleRaw = style.rawValue
                } label: {
                    Text(style.title)
                        .font(.caption)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .foregroundStyle(speakStyle == style ? KupifaTheme.lime : KupifaTheme.muted)
                        .background { pillBackground(selected: speakStyle == style) }
                }
                .buttonStyle(.plain)
                .help(style.title)
            }

            Spacer()

            Picker("声", selection: $grokVoiceRaw) {
                ForEach(GrokVoice.allCases) { voice in
                    Text(voice.displayName).tag(voice.rawValue)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .tint(KupifaTheme.muted)
            .help("Grok の読み上げ音声")
        }
    }

    // MARK: - 履歴サイドバー

    private var historySidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("履歴")
                    .font(.caption)
                    .foregroundStyle(KupifaTheme.muted)
                Spacer()
                if !history.isEmpty {
                    Button {
                        history = []
                        HistoryStore.save([])
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .controlSize(.small)
                    .foregroundStyle(KupifaTheme.muted)
                    .help("履歴をすべて削除")
                }
            }

            if history.isEmpty {
                Text("まだありません")
                    .font(.caption)
                    .foregroundStyle(KupifaTheme.muted)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(history) { entry in
                            historyRow(entry)
                        }
                    }
                }
            }
        }
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
        Button {
            restore(entry)
        } label: {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.input)
                        .font(.caption)
                        .foregroundStyle(KupifaTheme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        Text(entry.date, format: .relative(presentation: .named))
                        if !entry.savedResults.isEmpty {
                            Image(systemName: "text.bubble")
                                .help("出力結果も保存されています")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(KupifaTheme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .background {
                if entry.id == currentHistoryID {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(KupifaTheme.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(KupifaTheme.line, lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .help("クリックで入力欄に復元")
    }

    private func restore(_ entry: HistoryEntry) {
        cancelRunningTasks()
        switchMode(to: entry.actionMode)
        inputText = entry.input
        lastInput = entry.input
        lastMode = entry.actionMode
        currentHistoryID = entry.id
        copiedProviderID = nil

        // 保存済みの出力結果があれば結果カードも復元する
        let saved = entry.savedResults
        runs = AIProvider.allCases.compactMap { provider in
            let providerResults = saved.filter { $0.provider == provider.rawValue }
            guard !providerResults.isEmpty else { return nil }
            var states: [OutputLanguage: ModelRun.RunState] = [:]
            for result in providerResults {
                if let language = OutputLanguage(rawValue: result.language) {
                    states[language] = .success(result.text)
                }
            }
            let display = states[outputLanguage] != nil
                ? outputLanguage
                : (states.keys.first ?? outputLanguage)
            return ModelRun(provider: provider, displayLanguage: display, states: states)
        }

        inputFocused = true
    }

    // MARK: - 結果カード

    private func resultCard(run: ModelRun, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(run.provider.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KupifaTheme.lime)

                switch run.currentState {
                case .loading, .streaming:
                    ProgressView().controlSize(.small).tint(KupifaTheme.lime)
                case .failure:
                    Label("エラー", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                case .success:
                    EmptyView()
                }

                if let status = run.currentState.loadingStatus {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(KupifaTheme.muted)
                }

                Spacer()

                languageSwitch(for: run)

                if run.resultText != nil {
                    let copied = copiedProviderID == run.id
                    Button {
                        copy(run: run)
                    } label: {
                        Text(copied ? "コピーしました" : "コピー")
                            .font(.caption)
                            .foregroundStyle(copied ? KupifaTheme.lime : KupifaTheme.muted)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .shift])
                    .help("⌘⇧\(index + 1) でコピー（生成中も可）")
                }
            }

            if lastMode == .speak, run.provider == .grok {
                speakPlaybackBar
            }

            // 本文はカード内スクロールにして、パネル全体を下にスクロールさせない
            ScrollView {
                switch run.currentState {
                case .loading(let status):
                    VStack(alignment: .leading, spacing: 4) {
                        Text(status)
                            .font(.callout)
                            .foregroundStyle(KupifaTheme.muted)
                        if status.contains("考え"), run.provider == .grok {
                            Text("回答前の推論中です。この段階が長くなることがあります")
                                .font(.caption2)
                                .foregroundStyle(KupifaTheme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                case .failure(let message):
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(KupifaTheme.danger)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .streaming(let text):
                    Text(text.isEmpty ? "生成中…" : text)
                        .font(.system(size: 14))
                        .foregroundStyle(text.isEmpty ? KupifaTheme.muted : KupifaTheme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .success(let text):
                    Text(text)
                        .font(.system(size: 14))
                        .foregroundStyle(KupifaTheme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(KupifaTheme.lime.opacity(0.28), lineWidth: 1)
        }
    }

    /// 日 ⇄ EN のスイッチ。切り替えると未生成側はLLMで翻訳される
    private func languageSwitch(for run: ModelRun) -> some View {
        HStack(spacing: 4) {
            ForEach(OutputLanguage.allCases) { language in
                Button {
                    setDisplayLanguage(language, for: run.provider)
                } label: {
                    Text(language == .japanese ? "日" : "EN")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(run.displayLanguage == language ? KupifaTheme.lime : KupifaTheme.muted)
                        .background { pillBackground(selected: run.displayLanguage == language) }
                }
                .buttonStyle(.plain)
            }
        }
        .help("表示言語の切り替え（未生成の言語はAIが翻訳します）")
    }

    private var speakPlaybackBar: some View {
        HStack(spacing: 8) {
            Button {
                speechPlayer.toggle()
            } label: {
                Image(systemName: speechPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .foregroundStyle(speechPlayer.hasAudio ? KupifaTheme.lime : KupifaTheme.muted)
            }
            .disabled(!speechPlayer.hasAudio)
            .help(speechPlayer.isPlaying ? "一時停止" : "再生")

            Button {
                speechPlayer.stop()
                speechPlayer.play()
            } label: {
                Image(systemName: "backward.end.fill")
                    .foregroundStyle(speechPlayer.hasAudio ? KupifaTheme.ink : KupifaTheme.muted)
            }
            .disabled(!speechPlayer.hasAudio)
            .help("最初から再生")

            if isSynthesizingSpeech {
                ProgressView().controlSize(.mini).tint(KupifaTheme.lime)
                Text("音声を生成中…")
                    .font(.caption2)
                    .foregroundStyle(KupifaTheme.muted)
            } else if let speechError {
                Text(speechError)
                    .font(.caption2)
                    .foregroundStyle(KupifaTheme.danger)
                    .lineLimit(2)
            } else if speechPlayer.hasAudio {
                Text("\(formatTime(speechPlayer.currentTime)) / \(formatTime(speechPlayer.duration))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(KupifaTheme.muted)
            }

            Spacer()
        }
        .buttonStyle(.plain)
    }

    // MARK: - ロジック

    private var speakStyle: SpeakStyle {
        SpeakStyle(rawValue: speakStyleRaw) ?? .plain
    }

    private var grokVoice: GrokVoice {
        GrokVoice(rawValue: grokVoiceRaw) ?? .eve
    }

    private var placeholder: String {
        switch mode {
        case .polish: "整えたい文章を入力…（例: メールの下書き）"
        case .reply: "返したい荒い内容 + 相手の原文を貼り付け…（例: ビジネスメールっぽく、などの指定も可）"
        case .translate: "翻訳したい文章を入力…（日本語↔英語は自動判定）"
        case .speak: "読み上げたい文章を入力、または HTML / Markdown をドロップ…"
        case .search: "調べたいことを入力…（Grokが Web検索します）"
        }
    }

    /// 翻訳・音声モードでは日英同時生成を使わない
    private var shouldGenerateBothLanguages: Bool {
        generateBothLanguages && mode != .translate && mode != .speak
    }

    /// 翻訳は入力言語の反対側。それ以外は設定の出力言語。
    private func resolvedOutputLanguage(for mode: ActionMode, input: String) -> OutputLanguage {
        mode == .translate ? LanguageDetector.translationTarget(for: input) : outputLanguage
    }

    private var translateDirectionHint: some View {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: 6) {
            if trimmed.isEmpty {
                Text("日本語と英語を自動判定")
                    .foregroundStyle(KupifaTheme.muted)
            } else {
                let source = LanguageDetector.detectSource(trimmed)
                Text(source.label)
                    .foregroundStyle(KupifaTheme.ink)
                Image(systemName: "arrow.right")
                    .foregroundStyle(KupifaTheme.muted)
                Text(source.other.label)
                    .foregroundStyle(KupifaTheme.lime)
                Text("自動判定")
                    .foregroundStyle(KupifaTheme.muted)
            }
            Spacer()
        }
        .font(.caption)
        .help("入力が日本語なら英語へ、英語なら日本語へ翻訳します")
    }

    private func switchMode(to newMode: ActionMode) {
        if mode == .speak && newMode != .speak {
            speechPlayer.reset()
            speechError = nil
            isSynthesizingSpeech = false
        }
        mode = newMode
        inputFocused = true
    }

    private func toggleOutputLanguage() {
        let newLanguage = outputLanguage.other
        outputLanguageRaw = newLanguage.rawValue
        // 表示中のカードもすべて切り替える
        for run in runs {
            setDisplayLanguage(newLanguage, for: run.provider)
        }
    }

    private func clearAll() {
        cancelRunningTasks()
        inputText = ""
        editorHasText = false
        runs = []
        copiedProviderID = nil
        currentHistoryID = nil
        lastInput = ""
        inputFocused = true
    }

    /// 他アプリの選択テキストを入力欄へセット（ホットキー起動時）
    private func applyPrefill(_ text: String) {
        cancelRunningTasks()
        inputText = text
        editorHasText = true
        runs = []
        copiedProviderID = nil
        currentHistoryID = nil
        lastInput = ""
        inputFocused = true
    }

    private func cancelRunningTasks() {
        runningTasks.forEach { $0.cancel() }
        runningTasks = []
        speechGeneration = UUID()
        speechPlayer.reset()
        speechError = nil
        isSynthesizingSpeech = false
    }

    private func run() {
        if mode == .speak {
            runSpeak()
            return
        }

        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        cancelRunningTasks()
        copiedProviderID = nil

        // 履歴に記録（直前と同じ内容なら重複させない）
        history = HistoryStore.appending(HistoryEntry(mode: mode, input: text), to: history)
        HistoryStore.saveAsync(history)
        currentHistoryID = history.first?.id

        let currentMode = mode
        lastInput = text
        lastMode = currentMode
        let targetLanguage = resolvedOutputLanguage(for: currentMode, input: text)
        let languages: [OutputLanguage] = shouldGenerateBothLanguages ? OutputLanguage.allCases : [targetLanguage]

        _ = KeychainStore.apiKey(for: .grok)

        runs = [
            ModelRun(
                provider: .grok,
                displayLanguage: targetLanguage,
                states: Dictionary(uniqueKeysWithValues: languages.map { ($0, .loading(status: "接続中…")) })
            )
        ]

        runningTasks = languages.map { language in
            startStreamTask(provider: .grok, language: language, mode: currentMode, input: text)
        }
    }

    /// ストリーミング生成を開始し、到着分をカードに反映する
    private func startStreamTask(
        provider: AIProvider,
        language: OutputLanguage,
        mode: ActionMode,
        input: String
    ) -> Task<Void, Never> {
        Task {
            let prompt = PromptBuilder.build(
                mode: mode,
                input: input,
                outputLanguage: language,
                speakStyle: speakStyle
            )
            do {
                let result = try await AIService.stream(
                    prompt: prompt,
                    mode: mode
                ) { event in
                    Task { @MainActor in
                        handleStreamEvent(event, provider: provider, language: language)
                    }
                }
                guard !Task.isCancelled else { return }
                if let index = runs.firstIndex(where: { $0.provider == provider }) {
                    runs[index].states[language] = .success(result)
                }
                recordResult(result, provider: provider, language: language)
                if lastMode == .speak {
                    await playSpeech(for: result, language: language)
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                if let index = runs.firstIndex(where: { $0.provider == provider }) {
                    runs[index].states[language] = .failure(error.localizedDescription)
                }
            }
        }
    }

    @MainActor
    private func handleStreamEvent(_ event: StreamEvent, provider: AIProvider, language: OutputLanguage) {
        guard let index = runs.firstIndex(where: { $0.provider == provider }) else { return }
        switch event {
        case .connected:
            if case .loading = runs[index].states[language] {
                runs[index].states[language] = .loading(status: "応答待ち…")
            }
        case .thinking:
            if case .loading = runs[index].states[language] {
                runs[index].states[language] = .loading(status: "考え中…")
            }
        case .delta(let delta):
            let previous = runs[index].states[language]?.text ?? ""
            runs[index].states[language] = .streaming(previous + delta)
        }
    }

    /// 出力結果を現在の履歴エントリに保存する
    private func recordResult(_ text: String, provider: AIProvider, language: OutputLanguage) {
        guard let entryID = currentHistoryID else { return }
        history = HistoryStore.savingResult(
            text, provider: provider, language: language, entryID: entryID, in: history
        )
        HistoryStore.saveAsync(history)
    }

    /// カードの言語スイッチ切り替え。未生成の言語はLLMに翻訳させる
    private func setDisplayLanguage(_ language: OutputLanguage, for provider: AIProvider) {
        guard let index = runs.firstIndex(where: { $0.provider == provider }) else { return }
        runs[index].displayLanguage = language
        guard runs[index].states[language] == nil else { return }

        runs[index].states[language] = .loading(status: "接続中…")
        let sourceState = runs[index].states[language.other]
        let input = lastInput
        let currentMode = lastMode

        // 生成済みの結果があればそれをLLMで翻訳、なければ元の指示をその言語で再実行
        let promptInput: String
        let sendMode: ActionMode
        if case .success(let sourceText)? = sourceState {
            promptInput = sourceText
            sendMode = .translate
        } else if case .streaming(let sourceText)? = sourceState, !sourceText.isEmpty {
            promptInput = sourceText
            sendMode = .translate
        } else {
            promptInput = input
            sendMode = currentMode
        }

        runningTasks.append(
            startStreamTask(provider: provider, language: language, mode: sendMode, input: promptInput)
        )
    }

    private func copy(run: ModelRun) {
        guard let text = run.resultText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedProviderID = run.id
    }

    private func copyFirstResult() {
        if let first = runs.first(where: { $0.resultText != nil }) {
            copy(run: first)
        }
    }

    private func runSpeak() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        cancelRunningTasks()
        copiedProviderID = nil

        history = HistoryStore.appending(HistoryEntry(mode: .speak, input: text), to: history)
        HistoryStore.saveAsync(history)
        currentHistoryID = history.first?.id

        lastInput = text
        lastMode = .speak
        _ = KeychainStore.apiKey(for: .grok)

        let language = outputLanguage
        let status = speakStyle == .plain ? "音声を生成中…" : "原稿を作成中…"
        runs = [
            ModelRun(
                provider: .grok,
                displayLanguage: language,
                states: [language: .loading(status: status)]
            )
        ]

        if speakStyle == .plain {
            if let index = runs.firstIndex(where: { $0.provider == .grok }) {
                runs[index].states[language] = .success(text)
            }
            recordResult(text, provider: .grok, language: language)
            runningTasks = [Task { await playSpeech(for: text, language: language) }]
        } else {
            runningTasks = [startStreamTask(provider: .grok, language: language, mode: .speak, input: text)]
        }
    }

    private func playSpeech(for text: String, language: OutputLanguage) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let generation = UUID()
        speechGeneration = generation
        speechError = nil
        isSynthesizingSpeech = true
        speechPlayer.reset()
        do {
            _ = try await AIService.synthesizeSpeech(
                text: trimmed,
                language: language,
                voice: grokVoice
            ) { data, _, _ in
                Task { @MainActor in
                    guard speechGeneration == generation else { return }
                    do {
                        try speechPlayer.enqueue(data)
                        if !speechPlayer.isPlaying {
                            speechPlayer.play()
                        }
                    } catch {
                        speechError = error.localizedDescription
                    }
                }
            }
        } catch is CancellationError {
            if speechGeneration == generation {
                isSynthesizingSpeech = false
            }
            return
        } catch {
            guard speechGeneration == generation else { return }
            speechError = error.localizedDescription
        }
        if speechGeneration == generation {
            isSynthesizingSpeech = false
        }
    }

    /// TextEditor がファイルパスだけを挿入した場合は、中身を読み直す
    private func adoptDroppedFilePathIfNeeded(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("\n"), trimmed.count < 1024 else { return }

        let url: URL?
        if trimmed.hasPrefix("file:"), let parsed = URL(string: trimmed) {
            url = parsed
        } else if trimmed.hasPrefix("/") {
            url = URL(fileURLWithPath: trimmed)
        } else {
            return
        }

        guard let url,
              DroppedTextLoader.isSupported(url: url),
              FileManager.default.fileExists(atPath: url.path),
              let text = try? DroppedTextLoader.load(from: url)
        else { return }

        inputText = text
        editorHasText = true
        dropMessage = "ファイルを読み込みました"
        let captured = dropMessage
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if dropMessage == captured {
                dropMessage = nil
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let hasFile = providers.contains { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard hasFile else { return false }

        Task { @MainActor in
            var texts: [String] = []
            var lastError: Error?
            for provider in providers {
                do {
                    guard let url = try await loadDroppedFileURL(from: provider) else { continue }
                    texts.append(try DroppedTextLoader.load(from: url))
                } catch {
                    lastError = error
                }
            }
            if texts.isEmpty {
                dropMessage = lastError?.localizedDescription ?? DroppedTextError.unreadable.errorDescription
                return
            }
            let joined = texts.joined(separator: "\n\n")
            if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                inputText = joined
            } else {
                inputText += "\n\n" + joined
            }
            editorHasText = true
            dropMessage = texts.count == 1 ? "ファイルを読み込みました" : "\(texts.count)件のファイルを読み込みました"
            let captured = dropMessage
            try? await Task.sleep(for: .seconds(2))
            if dropMessage == captured {
                dropMessage = nil
            }
        }
        return true
    }

    private func loadDroppedFileURL(from provider: NSItemProvider) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }
                if let nsurl = item as? NSURL {
                    continuation.resume(returning: nsurl as URL)
                    return
                }
                if let data = item as? Data {
                    continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil))
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let total = max(0, Int(time.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// ショートカットキーがあるモードだけ ⌘N を付与する
private struct ModeShortcutModifier: ViewModifier {
    let key: Character?

    func body(content: Content) -> some View {
        if let key {
            content.keyboardShortcut(KeyEquivalent(key), modifiers: .command)
        } else {
            content
        }
    }
}

#Preview {
    QuickInputView(onClose: {})
}
