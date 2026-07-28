//
//  QuickInputView.swift
//  kupifa
//
//  ホットキーで表示されるメインのフォーム画面。
//  背景はシステム外観に追従した不透明2パターン（ライト: 白 / ダーク: 黒）。
//

import SwiftUI

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
    @State private var provider: AIProvider = defaultProvider()
    @State private var runAllModels = false
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

    @AppStorage(SettingsKeys.outputLanguage) private var outputLanguageRaw = OutputLanguage.japanese.rawValue
    @AppStorage(SettingsKeys.generateBothLanguages) private var generateBothLanguages = false
    @AppStorage(SettingsKeys.preferSpeed) private var preferSpeed = true

    @FocusState private var inputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var outputLanguage: OutputLanguage {
        OutputLanguage(rawValue: outputLanguageRaw) ?? .japanese
    }

    private var isLoading: Bool {
        runs.contains { run in
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
            header
            Divider()
                .opacity(0.4)
            content
        }
        .frame(minWidth: panelMinWidth, minHeight: 440)
        .background(panelBackground)
        .onAppear { inputFocused = true }
        .onDisappear { cancelRunningTasks() }
        .onReceive(NotificationCenter.default.publisher(for: .kupifaPrefillInput)) { note in
            guard let text = note.object as? String,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return }
            applyPrefill(text)
        }
        .background { hiddenShortcuts }
    }

    // MARK: - 背景（ライト: 白 / ダーク: 黒）

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(colorScheme == .dark ? Color.black : Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
            }
    }

    /// 入力欄・結果カードの面
    private func innerSurface(cornerRadius: CGFloat = 12) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.primary.opacity(0.06))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }

    // MARK: - ヘッダー（モード切替・実行対象）

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                showHistory.toggle()
            } label: {
                Image(systemName: "sidebar.left")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("0", modifiers: .command)
            .help("履歴の表示/非表示（⌘0）")

            ForEach(ActionMode.visibleCases) { m in
                Button {
                    switchMode(to: m)
                } label: {
                    Label(m.title, systemImage: m.icon)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background {
                            Capsule()
                                .fill(mode == m ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.05))
                                .overlay {
                                    Capsule().strokeBorder(
                                        mode == m ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.08),
                                        lineWidth: 1
                                    )
                                }
                        }
                }
                .buttonStyle(.plain)
                .modifier(ModeShortcutModifier(key: m.shortcutKey))
                .help(m.shortcutKey.map { "⌘\($0) で切り替え" } ?? m.title)
            }

            Spacer()

            Toggle(isOn: $preferSpeed) {
                Text("速さ優先")
            }
            .toggleStyle(.checkbox)
            .help("高速モデルと短い出力上限を使う（⌘F）")

            Toggle(isOn: $runAllModels) {
                Text("全モデル")
            }
            .toggleStyle(.checkbox)
            .disabled(mode == .search)
            .help("⌘M: 全モデル同時実行の切り替え（検索はGrokのみ・遅くなる）")

            if !runAllModels || mode == .search {
                Picker("", selection: $provider) {
                    ForEach(availableProviders) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .help("⌘P で切り替え")
            }

            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .help("設定を開く（⌘,）")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    /// 見た目を持たないショートカット専用ボタン群
    private var hiddenShortcuts: some View {
        Group {
            Button("", action: toggleRunAllModels)
                .keyboardShortcut("m", modifiers: .command)
            Button("", action: { preferSpeed.toggle() })
                .keyboardShortcut("f", modifiers: .command)
            Button("", action: cycleProvider)
                .keyboardShortcut("p", modifiers: .command)
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
        ZStack(alignment: .topLeading) {
            TextEditor(text: $inputText)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .focused($inputFocused)

            if inputText.isEmpty && !editorHasText {
                // 同じTextEditorを重ねることで、テキスト開始位置（インセット）を完全に一致させる
                TextEditor(text: .constant(placeholder))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .scrollContentBackground(.hidden)
                    .disabled(true)
                    .allowsHitTesting(false)
            }
        }
        .padding(8)
        .frame(minHeight: 90)
        .background(innerSurface())
        // SwiftUIのバインディングはIME変換確定まで更新されないため、
        // NSTextViewの変更通知（未確定文字でも発火する）でプレースホルダーを即座に消す
        .onReceive(NotificationCenter.default.publisher(for: NSText.didChangeNotification)) { note in
            guard let textView = note.object as? NSTextView,
                  textView.window is NSPanel else { return }
            editorHasText = !textView.string.isEmpty || textView.hasMarkedText()
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            // 履歴サイドバー（一番左）
            if showHistory {
                historySidebar
                    .frame(width: 180)

                Divider().opacity(0.4)
            }

            inputColumn
                .frame(minWidth: 280)
                .frame(maxWidth: runs.isEmpty ? .infinity : 340)

            // 結果は入力欄の右横に、モデルごとの縦カラムで並べる
            if !runs.isEmpty {
                Divider().opacity(0.4)

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
    }

    private var inputColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            inputEditor

            HStack {
                Button {
                    run()
                } label: {
                    if isLoading {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("生成中…")
                        }
                    } else {
                        Label("実行", systemImage: "paperplane.fill")
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help(isLoading ? "再実行すると進行中の生成をキャンセルします" : "⌘⏎ で実行")

                Button {
                    clearAll()
                } label: {
                    Label("新規", systemImage: "plus")
                }
                .help("入力と結果をクリアして新規作成（⌘K）")
                .disabled(inputText.isEmpty && runs.isEmpty && !editorHasText)

                Spacer()

                if preferSpeed {
                    Text("速さ優先")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text("⌘⏎ 実行 ・ ⌘K 新規 ・ ⌘F 速さ ・ ⌘M 全モデル ・ ⌘L 言語 ・ Esc 閉じる")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .help("⌘1 整える ・ ⌘2 返事作成 ・ ⌘3 翻訳")
        }
    }

    // MARK: - 履歴サイドバー

    private var historySidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("履歴")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
                    .help("履歴をすべて削除")
                }
            }

            if history.isEmpty {
                Text("まだありません")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
                Image(systemName: entry.actionMode.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.input)
                        .font(.caption)
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
                    .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .background(innerSurface(cornerRadius: 8))
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
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.2)))

                switch run.currentState {
                case .loading, .streaming:
                    ProgressView().controlSize(.small)
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
                        .foregroundStyle(.secondary)
                }

                Spacer()

                languageSwitch(for: run)

                if run.resultText != nil {
                    let copied = copiedProviderID == run.id
                    Button {
                        copy(run: run)
                    } label: {
                        Label(copied ? "コピーしました" : "コピー", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .controlSize(.small)
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .shift])
                    .help("⌘⇧\(index + 1) でコピー（生成中も可）")
                }
            }

            // 本文はカード内スクロールにして、パネル全体を下にスクロールさせない
            ScrollView {
                switch run.currentState {
                case .loading(let status):
                    VStack(alignment: .leading, spacing: 4) {
                        Text(status)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        if status.contains("考え"), run.provider == .grok {
                            Text("回答前の推論中です。この段階が長くなることがあります")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                case .failure(let message):
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .streaming(let text):
                    Text(text.isEmpty ? "生成中…" : text)
                        .font(.system(size: 14))
                        .foregroundStyle(text.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .success(let text):
                    Text(text)
                        .font(.system(size: 14))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(innerSurface())
    }

    /// 日 ⇄ EN のスイッチ。切り替えると未生成側はLLMで翻訳される
    private func languageSwitch(for run: ModelRun) -> some View {
        HStack(spacing: 4) {
            Text("日")
                .font(.caption2)
                .foregroundStyle(run.displayLanguage == .japanese ? .primary : .tertiary)
            Toggle("", isOn: Binding(
                get: { run.displayLanguage == .english },
                set: { setDisplayLanguage($0 ? .english : .japanese, for: run.provider) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            Text("EN")
                .font(.caption2)
                .foregroundStyle(run.displayLanguage == .english ? .primary : .tertiary)
        }
        .help("表示言語の切り替え（未生成の言語はAIが翻訳します）")
    }

    // MARK: - ロジック

    private var placeholder: String {
        switch mode {
        case .polish: "整えたい文章を入力…（例: メールの下書き）"
        case .reply: "返したい荒い内容 + 相手の原文を貼り付け…（例: ビジネスメールっぽく、などの指定も可）"
        case .translate: "翻訳したい文章を入力…"
        case .search: "調べたいことを入力…（Grokが Web検索します）"
        }
    }

    /// 翻訳モードでは日英同時生成を使わない
    private var shouldGenerateBothLanguages: Bool {
        generateBothLanguages && mode != .translate
    }

    private var availableProviders: [AIProvider] {
        mode == .search ? AIProvider.allCases.filter(\.supportsSearch) : AIProvider.allCases
    }

    /// この実行で対象になるプロバイダ一覧
    private var targetProviders: [AIProvider] {
        if mode == .search { return [.grok] }
        guard runAllModels else { return [provider] }
        // 全モデル実行時はAPIキー登録済みのものだけを対象にする
        let configured = AIProvider.allCases.filter { KeychainStore.apiKey(for: $0) != nil }
        return configured.isEmpty ? [provider] : configured
    }

    private func switchMode(to newMode: ActionMode) {
        mode = newMode
        if newMode == .search && !provider.supportsSearch {
            provider = .grok
        }
        inputFocused = true
    }

    private func toggleRunAllModels() {
        guard mode != .search else { return }
        runAllModels.toggle()
    }

    private func toggleOutputLanguage() {
        let newLanguage = outputLanguage.other
        outputLanguageRaw = newLanguage.rawValue
        // 表示中のカードもすべて切り替える
        for run in runs {
            setDisplayLanguage(newLanguage, for: run.provider)
        }
    }

    private func cycleProvider() {
        let providers = availableProviders
        guard let current = providers.firstIndex(of: provider) else {
            provider = providers.first ?? .grok
            return
        }
        provider = providers[(current + 1) % providers.count]
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
    }

    private func run() {
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
        let languages: [OutputLanguage] = shouldGenerateBothLanguages ? OutputLanguage.allCases : [outputLanguage]

        // キーを先読みして並列リクエスト時のKeychainアクセスを減らす
        for p in targetProviders {
            _ = KeychainStore.apiKey(for: p)
        }

        runs = targetProviders.map { p in
            ModelRun(
                provider: p,
                displayLanguage: outputLanguage,
                states: Dictionary(uniqueKeysWithValues: languages.map { ($0, .loading(status: "接続中…")) })
            )
        }

        // プロバイダ × 言語 の全組み合わせを並列ストリーミング
        runningTasks = targetProviders.flatMap { p in
            languages.map { language in
                startStreamTask(provider: p, language: language, mode: currentMode, input: text)
            }
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
            let prompt = PromptBuilder.build(mode: mode, input: input, outputLanguage: language)
            do {
                let result = try await AIService.stream(
                    prompt: prompt,
                    provider: provider,
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

    private static func defaultProvider() -> AIProvider {
        UserDefaults.standard.string(forKey: SettingsKeys.defaultProvider)
            .flatMap(AIProvider.init(rawValue:)) ?? .claude
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
