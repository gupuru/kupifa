//
//  DroppedTextLoader.swift
//  kupifa
//
//  ドラッグ&ドロップされた HTML / Markdown / テキストを入力欄用の文字列にする。
//

import Foundation

enum DroppedTextError: LocalizedError {
    case unsupportedType
    case tooLarge
    case unreadable
    case empty

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            "HTML / Markdown / テキストファイルのみドロップできます。"
        case .tooLarge:
            "ファイルが大きすぎます（2MBまで）。"
        case .unreadable:
            "ファイルを読み取れませんでした。"
        case .empty:
            "ファイルに読み取れるテキストがありません。"
        }
    }
}

enum DroppedTextLoader {
    static let supportedExtensions: Set<String> = ["html", "htm", "md", "markdown", "txt"]
    static let maxBytes = 2_000_000

    static func isSupported(url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func load(from url: URL) throws -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        guard isSupported(url: url) else { throw DroppedTextError.unsupportedType }

        let data = try Data(contentsOf: url)
        guard data.count <= maxBytes else { throw DroppedTextError.tooLarge }

        guard let raw = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .shiftJIS)
            ?? String(data: data, encoding: .japaneseEUC)
        else {
            throw DroppedTextError.unreadable
        }

        let ext = url.pathExtension.lowercased()
        let text: String
        if ext == "html" || ext == "htm" {
            text = htmlToPlainText(raw)
        } else {
            text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !text.isEmpty else { throw DroppedTextError.empty }
        return text
    }

    static func htmlToPlainText(_ html: String) -> String {
        var s = html
        for tag in ["script", "style", "noscript", "svg", "head"] {
            s = removeTagBlocks(s, tag: tag)
        }

        s = replaceRegex(#"(?is)<br\s*/?>"#, in: s, with: "\n")
        for tag in ["p", "div", "tr", "li", "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "section", "article", "pre"] {
            s = replaceRegex("(?is)</\(tag)\\s*>", in: s, with: "\n")
        }

        s = replaceRegex(#"<[^>]+>"#, in: s, with: "")
        s = decodeHTMLEntities(s)
        return normalizeBlankLines(s)
    }

    private static func removeTagBlocks(_ html: String, tag: String) -> String {
        replaceRegex("(?is)<\(tag)\\b[^>]*>.*?</\(tag)\\s*>", in: html, with: "\n")
    }

    private static func replaceRegex(_ pattern: String, in text: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

    static func decodeHTMLEntities(_ text: String) -> String {
        var s = text
        let named: [(String, String)] = [
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&mdash;", "—"),
            ("&ndash;", "–"),
            ("&hellip;", "…"),
        ]
        for (entity, value) in named {
            s = s.replacingOccurrences(of: entity, with: value)
        }

        if let hex = try? NSRegularExpression(pattern: #"&#x([0-9a-fA-F]+);"#) {
            s = replaceMatches(hex, in: s) { match in
                guard let code = Int(match, radix: 16), let scalar = UnicodeScalar(code) else { return match }
                return String(Character(scalar))
            }
        }
        if let dec = try? NSRegularExpression(pattern: #"&#(\d+);"#) {
            s = replaceMatches(dec, in: s) { match in
                guard let code = Int(match), let scalar = UnicodeScalar(code) else { return match }
                return String(Character(scalar))
            }
        }
        return s
    }

    private static func replaceMatches(
        _ regex: NSRegularExpression,
        in text: String,
        transform: (String) -> String
    ) -> String {
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var result = text
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2,
                  let full = Range(match.range, in: result),
                  let cap = Range(match.range(at: 1), in: result)
            else { continue }
            result.replaceSubrange(full, with: transform(String(result[cap])))
        }
        return result
    }

    static func normalizeBlankLines(_ text: String) -> String {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var result: [String] = []
        var blank = false
        for line in lines {
            if line.isEmpty {
                if !result.isEmpty { blank = true }
                continue
            }
            if blank {
                result.append("")
                blank = false
            }
            result.append(line)
        }
        return result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// TTS の 15,000 文字制限に合わせて文境界で分割する
enum TextChunker {
    static let ttsLimit = 12_000

    static func split(_ text: String, maxLength: Int = ttsLimit) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard trimmed.count > maxLength else { return [trimmed] }

        var chunks: [String] = []
        var current = ""

        func flush() {
            let piece = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { chunks.append(piece) }
            current = ""
        }

        func appendPiece(_ piece: String) {
            if piece.count > maxLength {
                flush()
                var rest = piece
                while rest.count > maxLength {
                    let idx = rest.index(rest.startIndex, offsetBy: maxLength)
                    chunks.append(String(rest[..<idx]))
                    rest = String(rest[idx...])
                }
                current = rest
                return
            }
            if !current.isEmpty, current.count + 1 + piece.count > maxLength {
                flush()
            }
            current += current.isEmpty ? piece : "\n\n" + piece
        }

        let paragraphs = trimmed.components(separatedBy: "\n\n")
        for paragraph in paragraphs {
            if paragraph.count <= maxLength {
                appendPiece(paragraph)
                continue
            }
            let sentences = splitSentences(paragraph)
            for sentence in sentences {
                appendPiece(sentence)
            }
        }
        flush()
        return chunks
    }

    private static func splitSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if "。！？\n.!?".contains(character) {
                let piece = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !piece.isEmpty { sentences.append(piece) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { sentences.append(tail) }
        return sentences
    }
}
