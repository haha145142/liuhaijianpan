// Sources/AI/AIService.swift

// AIService 协议与 ChatContext 模型
// 目的：解耦 Keyboard UI 与不同的 AI 客户端实现（例如 GoutouAdapter）。

import Foundation

public struct ChatMessage: Codable {
    public let role: String // "user" / "assistant" / "system"
    public let content: String
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct ChatContext {
    public let inputText: String
    public let history: [ChatMessage]
    public let locale: String?

    public init(inputText: String, history: [ChatMessage] = [], locale: String? = nil) {
        self.inputText = inputText
        self.history = history
        self.locale = locale
    }
}

public enum AIServiceError: Error {
    case configuration(String)
    case network(Error)
    case server(statusCode: Int, message: String?)
    case decoding(Error)
    case unknown
}

public protocol AIService {
    static var shared: AIService { get }

    /// 请求一个回复。实现应保证在后台线程发起网络请求，并在 completion 中回到主线程或明确标注。
    func requestReply(context: ChatContext, completion: @escaping (Result<String, AIServiceError>) -> Void)
}
