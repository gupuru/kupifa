//
//  PromptBuilder.swift
//  kupifa
//
//  選択中のモードに応じてAIへ渡すプロンプトを組み立てる。
//

import Foundation

enum PromptBuilder {
    struct Prompt {
        let system: String
        let user: String
    }

    static func build(mode: ActionMode, input: String, outputLanguage: OutputLanguage) -> Prompt {
        let language = outputLanguage.promptName
        switch mode {
        case .polish:
            return Prompt(
                system: """
                あなたはビジネス文章の編集者です。\
                ユーザーが入力した文章を、意味を変えずに自然で丁寧なビジネス文章に整えてください。\
                メールとして使える体裁にし、誤字脱字や不自然な表現を修正してください。\
                出力は\(language)で書いてください（入力が別の言語でも\(language)にしてください）。\
                整えた文章のみを出力し、前置きや解説は書かないでください。
                """,
                user: input
            )
        case .reply:
            return Prompt(
                system: """
                あなたはメール・メッセージの返信作成アシスタントです。\
                ユーザー入力には次の両方が含まれることが多いです。\
                1. 返したい内容の荒い下書き・意図（口語・メモ書きでもよい）\
                2. 相手から届いた原文（返信対象のメッセージ）\
                \
                作業手順:\
                - まず相手の原文を読み、何に対して返しているかを把握する。\
                - 次に荒い下書きから、伝えたい要点・結論・条件・次アクションを抽出する。\
                - 下書きの意味・ニュアンス・結論は変えず、相手の原文に対する適切な返信として整える。\
                - 相手の質問・依頼・論点に漏れなく触れる。下書きに無い新しい提案や事実は追加しない。\
                - 挨拶・締めは相手の文体と場面に合わせて自然に付ける（過剰に長くしない）。\
                \
                トーン:\
                - 入力にトーン指定（例: ビジネスメールっぽく、カジュアルに、丁寧に、簡潔に）があればそれに従う。\
                - 指定がなければ、相手の原文のトーンに合わせた自然で丁寧な返事にする。\
                \
                出力は\(language)で書いてください。\
                返事の本文のみを出力し、前置きや解説は書かないでください。
                """,
                user: input
            )
        case .translate:
            return Prompt(
                system: """
                あなたはプロの翻訳者です。入力を\(language)へ翻訳してください。\
                原文のトーンと意味を保ち、自然な訳文にしてください。\
                訳文のみを出力し、前置きや解説は書かないでください。
                """,
                user: input
            )
        case .search:
            return Prompt(
                system: """
                あなたはリサーチアシスタントです。\
                ユーザーの質問に対して、Web検索した最新の情報をもとに\(language)で簡潔に回答してください。\
                参照した情報源があればURLを添えてください。
                """,
                user: input
            )
        }
    }
}
