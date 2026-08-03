//
//  AIService.swift
//  kupifa
//
//  Grok / Claude のAPIを直接叩く薄いクライアント（SSEストリーミング対応）。
//

import Foundation

enum AIServiceError: LocalizedError {
    case missingAPIKey(AIProvider)
    case searchNotSupported(AIProvider)
    case httpError(statusCode: Int, body: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            "\(provider.displayName) のAPIキーが未設定です。設定画面（⌘,）から登録してください。"
        case .searchNotSupported(let provider):
            "検索モードは Grok のみ対応です（現在: \(provider.displayName)）。"
        case .httpError(let statusCode, let body):
            "APIエラー（HTTP \(statusCode)）: \(body.prefix(300))"
        case .emptyResponse:
            "AIから空の応答が返されました。"
        }
    }
}

/// ストリーム進行状況（本文前の待ちをUIで段階表示するため）
enum StreamEvent: Sendable {
    /// HTTPレスポンスヘッダ受信（TLS・接続完了）
    case connected
    /// モデルが動き始めた（reasoning / 最初のSSEなど）。本文はまだ
    case thinking
    /// 本文トークン
    case delta(String)
}

struct AIService {
    typealias EventHandler = @Sendable (StreamEvent) -> Void

    /// Keep-Alive で接続を再利用するセッション
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = false
        config.httpMaximumConnectionsPerHost = 4
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    /// APIホストへのTLSを先に張っておく（パネル表示時・起動時）
    static func warmConnections() {
        let hosts = [
            "https://api.x.ai",
            "https://api.anthropic.com",
        ]
        for host in hosts {
            guard let url = URL(string: host) else { continue }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
            request.httpMethod = "HEAD"
            session.dataTask(with: request).resume()
        }
    }

    static func stream(
        prompt: PromptBuilder.Prompt,
        provider: AIProvider,
        mode: ActionMode,
        onEvent: EventHandler? = nil
    ) async throws -> String {
        if mode == .search && !provider.supportsSearch {
            throw AIServiceError.searchNotSupported(provider)
        }
        guard let apiKey = KeychainStore.apiKey(for: provider) else {
            throw AIServiceError.missingAPIKey(provider)
        }

        let preferSpeed = UserDefaults.standard.object(forKey: SettingsKeys.preferSpeed) as? Bool ?? true
        let model = provider.resolvedModel(preferSpeed: preferSpeed)
        let maxTokens = Self.maxTokens(mode: mode, preferSpeed: preferSpeed)

        switch provider {
        case .grok:
            return try await streamGrok(
                prompt: prompt,
                apiKey: apiKey,
                model: model,
                enableSearch: mode == .search,
                preferSpeed: preferSpeed,
                maxTokens: maxTokens,
                onEvent: onEvent
            )
        case .claude:
            return try await streamClaude(
                prompt: prompt,
                apiKey: apiKey,
                model: model,
                maxTokens: maxTokens,
                onEvent: onEvent
            )
        }
    }

    private static func maxTokens(mode: ActionMode, preferSpeed: Bool) -> Int {
        switch mode {
        case .search: preferSpeed ? 2048 : 4096
        default: preferSpeed ? 1024 : 2048
        }
    }

    // MARK: - Grok (x.ai / OpenAI互換 Chat Completions)

    private static func streamGrok(
        prompt: PromptBuilder.Prompt,
        apiKey: String,
        model: String,
        enableSearch: Bool,
        preferSpeed: Bool,
        maxTokens: Int,
        onEvent: EventHandler?
    ) async throws -> String {
        var body: [String: Any] = [
            "model": model,
            "stream": true,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": prompt.system],
                ["role": "user", "content": prompt.user],
            ],
        ]
        if enableSearch {
            body["search_parameters"] = ["mode": "on", "return_citations": true]
        }
        // 速さ優先時は reasoning を抑える（4.5 は none 不可のため low）
        if preferSpeed {
            if model.contains("grok-4.3") {
                body["reasoning_effort"] = "none"
            } else if model.contains("grok-4.5") {
                body["reasoning_effort"] = "low"
            }
        }

        final class CitationBox: @unchecked Sendable {
            var values: [String] = []
        }
        let citationBox = CitationBox()

        let text = try await streamSSE(
            url: URL(string: "https://api.x.ai/v1/chat/completions")!,
            headers: ["Authorization": "Bearer \(apiKey)"],
            body: body,
            onEvent: onEvent
        ) { json, emitThinking in
            if let cite = json["citations"] as? [String], !cite.isEmpty {
                citationBox.values = cite
            }
            guard
                let choices = json["choices"] as? [[String: Any]],
                let delta = choices.first?["delta"] as? [String: Any]
            else { return nil }

            // reasoning 中は本文が来ないので「考え中」へ進める
            if let reasoning = delta["reasoning_content"] as? String, !reasoning.isEmpty {
                emitThinking()
            } else if delta["content"] == nil {
                emitThinking()
            }

            guard let content = delta["content"] as? String, !content.isEmpty else { return nil }
            return content
        }

        guard !text.isEmpty else { throw AIServiceError.emptyResponse }

        if !citationBox.values.isEmpty {
            let sources = citationBox.values.prefix(5).map { "- \($0)" }.joined(separator: "\n")
            return text + "\n\n参照元:\n" + sources
        }
        return text
    }

    // MARK: - Claude (Anthropic Messages API)

    private static func streamClaude(
        prompt: PromptBuilder.Prompt,
        apiKey: String,
        model: String,
        maxTokens: Int,
        onEvent: EventHandler?
    ) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": true,
            "system": prompt.system,
            "messages": [
                ["role": "user", "content": prompt.user]
            ],
        ]

        let text = try await streamSSE(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
            ],
            body: body,
            onEvent: onEvent
        ) { json, emitThinking in
            let type = json["type"] as? String
            if type == "message_start" || type == "content_block_start" {
                emitThinking()
            }
            guard
                type == "content_block_delta",
                let delta = json["delta"] as? [String: Any],
                let text = delta["text"] as? String,
                !text.isEmpty
            else { return nil }
            return text
        }

        guard !text.isEmpty else { throw AIServiceError.emptyResponse }
        return text
    }

    // MARK: - SSE共通

    private static func streamSSE(
        url: URL,
        headers: [String: String],
        body: [String: Any],
        onEvent: EventHandler?,
        parseDelta: (_ json: [String: Any], _ emitThinking: () -> Void) -> String?
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
                if errorBody.count > 2000 { break }
            }
            throw AIServiceError.httpError(statusCode: http.statusCode, body: errorBody)
        }

        onEvent?(.connected)

        var accumulated = ""
        var didEmitThinking = false
        let emitThinking = {
            guard !didEmitThinking else { return }
            didEmitThinking = true
            onEvent?(.thinking)
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard !payload.isEmpty, payload != "[DONE]" else {
                if payload == "[DONE]" { break }
                continue
            }
            guard
                let data = payload.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            if let delta = parseDelta(json, emitThinking) {
                accumulated += delta
                onEvent?(.delta(delta))
            }
        }
        return accumulated
    }
}
