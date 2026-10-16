// Sources/AI/Goutou/GoutouAIClient.swift

// Migrated from https://github.com/haha145142/goutou-keyboard-ios
// Keep original logic but adapt a few access modifiers and remove UI dependencies.

import Foundation

/// 军师返回给面板的东西。
public struct GoutouResult: Equatable {
    public let headline: String
    public let replies: [String]
}

public enum GoutouAIError: Error, Equatable {
    case notConfigured
    case badURL
    case timeout
    case network(String)
    case http(Int, String)
    case empty
    case badJSON(String)
    case reasoningOnly(Bool)
    case truncated

    public var message: String {
        switch self {
        case .notConfigured:
            return "还没配置 AI 接口"
        case .badURL:
            return "Base URL 不合法，要带 https:// 那种完整地址"
        case .timeout:
            return "请求超时（\(Int(GoutouAIClient.timeout)) 秒)"
        case .network(let detail):
            return "网络请求失败：\(detail)"
        case .http(let code, let detail):
            return "接口返回 HTTP \(code)\(detail.isEmpty ? "" : "：\(detail)")"
        case .empty:
            return "接口返回的是空内容"
        case .badJSON(let snippet):
            return snippet.isEmpty ? "接口返回的不是约定格式的 JSON" : "接口返回的不是约定格式的 JSON（开头是：\(snippet)）"
        case .reasoningOnly(let truncated):
            return truncated ? "模型把 token 都花在思考上了，正文被截断。把 Model 换成非推理的（例如 deepseek-reasoner → deepseek-chat），或把上下文缩短再试" : "模型只返回了思考内容、没有正文。把 Model 换成非推理的（例如 deepseek-reasoner → deepseek-chat）再试"
        case .truncated:
            return "模型输出被截断（token 用完了），没能给完整的 JSON。把上下文缩短、或换输出更短的模型再试"
        }
    }
}

public enum GoutouAIClient {

    public static let timeout: TimeInterval = 60
    public static let temperature = 0.6
    public static let maxTokens = 8192

    public static func buildURLRequest(
        config: GoutouConfig,
        systemPrompt: String,
        userMessage: String
    ) throws -> URLRequest {
        guard config.isReady else { throw GoutouAIError.notConfigured }
        guard let url = config.chatCompletionsURL else { throw GoutouAIError.badURL }
        let scheme = url.scheme?.lowercased()
        guard scheme == "https" || scheme == "http" else { throw GoutouAIError.badURL }

        let body: [String: Any] = [
            "model": config.model.trimmed,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage],
            ],
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": false,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !config.apiKey.trimmed.isEmpty {
            request.setValue("Bearer \(config.apiKey.trimmed)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    public static func parseResponse(data: Data) throws -> GoutouResult {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw GoutouAIError.badJSON(snippet(String(data: data, encoding: .utf8) ?? ""))
        }
        if let error = root["error"] as? [String: Any] {
            let detail = (error["message"] as? String) ?? (error["code"] as? String) ?? ""
            throw GoutouAIError.http(0, detail)
        }
        guard let choices = root["choices"] as? [[String: Any]], let first = choices.first else {
            throw GoutouAIError.empty
        }
        guard let message = first["message"] as? [String: Any] else { throw GoutouAIError.empty }
        let truncated = (first["finish_reason"] as? String) == "length"

        let text = stripThinking(extractText(from: message)).trimmed
        let reasoning = stripThinking(
            (message["reasoning_content"] as? String) ?? (message["reasoning"] as? String) ?? ""
        ).trimmed

        if let result = buildResult(fromText: text) { return result }
        if !reasoning.isEmpty, let result = buildResult(fromText: reasoning) { return result }

        if !reasoning.isEmpty { throw GoutouAIError.reasoningOnly(truncated) }
        if text.isEmpty { throw GoutouAIError.empty }
        throw truncated ? GoutouAIError.truncated : GoutouAIError.badJSON(snippet(text))
    }

    static func buildResult(fromText text: String) -> GoutouResult? {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty else { return nil }
        guard let payload = decodePayload(trimmed) ?? lenientFields(in: trimmed) else { return nil }

        let unwrapped = unwrapPayload(payload)
        let relationship = firstString(
            in: unwrapped,
            keys: ["relationship", "关系", "关系分析", "关系与氛围", "headline", "判断", "总结"]
        ) ?? ""
        let replies = normalizedReplies(from: unwrapped)

        let headline = GoutouPrompt.headline(fromRelationship: relationship)
        guard !headline.isEmpty || !replies.isEmpty else { return nil }
        return GoutouResult(headline: headline, replies: Array(replies.prefix(GoutouPrompt.maxReplies)))
    }

    // ... (rest of the original file is migrated unchanged, omitted for brevity in this snippet)
}
