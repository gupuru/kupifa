# kupifa

[![License: MIT](https://img.shields.io/badge/License-MIT-d8ff3e.svg)](LICENSE)

ホットキー一発で呼び出せる、macOS用のAIクイックアシスタント。**MIT ライセンス**のオープンソースです。

プロダクトサイト（`docs/`）: ホットキーで文章を整え、Grok に投げる、という使い方を先に見せています。公開先は [GitHub Pages](https://gupuru.github.io/kupifa/)。ソースと配布用 DMG も [GitHub](https://github.com/gupuru/kupifa) に置いています。

メール文章の下書きなど、書きかけのテキストをその場でAIに投げて「文章を整える」「翻訳」「音声で読む」ができる、Spotlight風のフローティングパネルアプリです。

## ライセンス

[MIT License](LICENSE) です。著作権表示を残したうえで、利用・改変・再配布・商用利用ができます。

## 主な機能

- **グローバルホットキー**（デフォルト: `⌥ Space`）でどこからでもパネルを呼び出し
- **4つのモード**をパネル上部のボタンで切り替え
  - 文章を整える（`⌘1`）: 入力した文章を自然なビジネス文章に整形
  - 返事作成（`⌘2`）: 相手の原文と返したい要点から返信を作成
  - 翻訳（`⌘3`）: 選択した出力言語へ翻訳
  - 音声で読む（`⌘4`）: 入力やドロップした文章を Grok が読み上げ（**Grokのみ対応**）。ただ読む / ラジオ風 / 要約版
- **ファイルのドロップ**: HTML / Markdown を入力欄へドラッグ&ドロップして本文を取り込める
- **結果カードの言語スイッチ（日 ⇄ EN）**: 各結果カードのコピー左のスイッチで表示言語を切り替え。未生成の言語はその場でAIが翻訳して表示（`⌘L` で全カード一括切り替え）
- **日英同時生成**（設定でON/OFF）: 実行時に日本語と英語の両方をあらかじめ生成し、スイッチ切り替えを瞬時にする
- **指示履歴**（`⌘0`）: 過去に実行した指示と出力結果をパネル左端のサイドバーに一覧表示。クリックで入力欄と結果カードをまとめて復元
- **Grok**: xAI の Grok を直接利用（整える・返事・翻訳・音声）
- **シンプルで見やすいUI**: LPと同じダーク＋ライムの不透明パネル。ブラーや常時アニメーションを使わないため動作が軽い
- メニューバー常駐（Dockには表示されません）

### キーボードショートカット（パネル内）

| キー | 動作 |
| --- | --- |
| `⌘1` / `⌘2` / `⌘3` / `⌘4` | モード切り替え（整える / 返事作成 / 翻訳 / 音声） |
| `⌘⏎` | 実行 |
| `⌘L` | 表示言語（日本語/英語）の切り替え |
| `⌘0` | 履歴サイドバーの表示/非表示 |
| `⌘K` | 入力と結果をクリア |
| `⌘⇧C` | 最初の結果をコピー |
| `⌘⇧1`〜`⌘⇧3` | N番目の結果カードをコピー |
| `⌘,` | 設定を開く |
| `⌘W` | パネルを閉じる（`Esc` でも閉じる） |

## 使い方

1. アプリを起動する（メニューバーに kupifa のマークが表示されます）
2. メニューバーのマーク →「設定…」（または `⌘,`）を開き、Grok のAPIキーを登録する（https://console.x.ai）
3. `⌥ Space` でパネルを呼び出す
4. モードを選び（`⌘1`〜`⌘4`）、文章を入力（または HTML / Markdown をドロップ）して `⌘⏎`
5. 結果をコピー（`⌘⇧C`）してメール等に貼り付け

> **⌘ Space を使いたい場合**: Spotlightのショートカットと競合します。システム設定 → キーボード → キーボードショートカット → Spotlight で無効化したうえで、本アプリの設定からホットキーを変更してください。

## セキュリティ

- APIキーは **macOSのキーチェーン** に保存されます
- 入力した文章は Grok（xAI）のAPIにのみ送信されます
- 選択テキスト取り込みのため App Sandbox は無効（アクセシビリティ許可が必要）

## 動作環境・ビルド

- macOS 15.0 以降（Apple Silicon）
- Xcode 26 以降

```bash
open kupifa.xcodeproj
# Xcodeで kupifa スキームを選んで Run (⌘R)
```

配布用の `.dmg` は Apple Silicon 向けです。ローカルでも作れます。

```bash
./scripts/build-release.sh
# 完成: dist/kupifa.dmg
```

いまは ad-hoc 署名です。Developer ID + 公証に移すときは、スクリプト先頭の `SIGN_IDENTITY` を変えて、`notarytool` / `stapler` を足してください。

## サイト公開・配布

サイトも `.dmg` も GitHub です。LP は `docs/` を編集して `main` に push すると [GitHub Pages](https://gupuru.github.io/kupifa/) に載ります。

| もの | 置き場 | URL |
| --- | --- | --- |
| ランディング（`docs/`） | GitHub Pages | https://gupuru.github.io/kupifa/ |
| `kupifa.dmg` | GitHub Releases | https://github.com/gupuru/kupifa/releases/latest/download/kupifa.dmg |

`docs/download.html` は latest の DMG へ転送します。デプロイは `.github/workflows/deploy.yml` です。

初回はリポジトリを public にし、Settings → Pages の Source を **GitHub Actions** にしてください。`main` への push でサイトが公開されます。

### サイトを更新する

`docs/` を直して `main` に push します。GitHub 上で `docs/index.html` を編集しても同じです。

### DMG を上げる

毎プッシュでは作りません（macOS runner が重いため）。どちらかです。

- GitHub Actions の **Deploy** を Run workflow し、`build_dmg` をオンにする
- `v0.1.0` のような `v*` タグを push する

上がると [Releases](https://github.com/gupuru/kupifa/releases) に `kupifa.dmg` が付きます。未作成のうちは latest のダウンロード URL が 404 です。

## アーキテクチャ

| ファイル | 役割 |
| --- | --- |
| `kupifaApp.swift` | アプリ本体（MenuBarExtra・ホットキー登録） |
| `QuickPanelController.swift` | フローティングパネル（NSPanel）の表示制御 |
| `QuickInputView.swift` | メインのフォームUI |
| `HotKeyManager.swift` | Carbonによるグローバルホットキー |
| `AIService.swift` | Grok APIクライアント（チャット・TTS） |
| `PromptBuilder.swift` | モード別プロンプト生成 |
| `DroppedTextLoader.swift` | HTML / Markdown のドロップ取り込み |
| `SpeechPlayer.swift` | Grok TTS の再生 |
| `KeychainStore.swift` | APIキーのキーチェーン保存 |
| `SettingsView.swift` | 設定画面（APIキー・モデル・ホットキー） |

## 将来構想（未実装）

現在はユーザー自身がAPIキーを用意するBYOK（Bring Your Own Key）方式ですが、将来的には以下を計画しています。

- **運営サーバー経由のAPI提供**: ユーザーがAPIキーを用意しなくても、課金（サブスクリプション）することで運営側のサーバーを経由して複数のAIモデルを利用できるようにする
  - クライアントは運営APIサーバーのみと通信し、サーバー側で Grok へルーティング
  - アカウント認証・利用量に応じたプラン・レート制限を導入
  - `AIService` はプロバイダ直叩きと運営API経由を切り替えられる構成に拡張予定
- モデルの追加（OpenAIなど）や、履歴・プリセットプロンプト機能
