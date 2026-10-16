import Foundation

// GoutouAdapter.swift
// 轻量级示例：把 ChatContext 转为一个 prompt，并调用远端 AI 服务返回字符串回复。
// 请不要将真实 API Key 写入代码。将 Secret 存为 GOUTOU_API_KEY，在运行时注入。

public final class GoutouAdapter: AIService {
    public static var shared: AIService = GoutouAdapter()

    private let session: URLSession
    private let apiKey: String
    private let apiURL: URL

    public init(apiKey: String? = nil, apiURL: URL? = nil, session: URLSession = .shared) {
        self.session = session
        // 优先从参数读取，再从环境变量读取，再使用占位符
        self.apiKey = apiKey ?? ProcessInfo.processInfo.environment["GOUTOU_API_KEY"] ?? ""
        if let url = apiURL {
            self.apiURL = url
        } else if let env = ProcessInfo.processInfo.environment["GOUTOU_API_URL"], let u = URL(string: env) {
            self.apiURL = u
        } else {
            // 默认占位，请替换为实际服务 URL
            self.apiURL = URL(string: "https://api.example.com/generate")!
        }
    }

    public func requestReply(context: ChatContext, completion: @escaping (Result<String, AIServiceError>) -> Void) {
        // 构造 prompt（示例策略：合并 history 和 input）
        var prompt = ""
        if !context.history.isEmpty {
            for msg in context.history {
                prompt += "\(msg.role): \(msg.content)\n"
            }
            prompt += "\n"
        }
        prompt += "User: \(context.inputText)\nAssistant:"

        var req = URLRequest(url: apiURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "prompt": prompt,
            "max_tokens": 512,
            "temperature": 0.8
        ]

        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(.configuration("failed to encode request body: \(error)")))
            return
        }

        let task = session.dataTask(with: req) { data, response, error in
            if let err = error {
                completion(.failure(.network(err)))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(.unknown))
                return
            }
            guard (200...299).contains(http.statusCode), let d = data else {
                var message: String? = nil
                if let d = data { message = String(data: d, encoding: .utf8) }
                completion(.failure(.server(statusCode: http.statusCode, message: message)))
                return
            }
            // 解析响应。不同后端格式不同，这里尝试解析常见的 { "text": "..." } 或 { "choices":[{"text":"..."}] }
            do {
                if let obj = try JSONSerialization.jsonObject(with: d, options: []) as? [String: Any] {
                    if let text = obj["text"] as? String {
                        completion(.success(text))
                        return
                    }
                    if let choices = obj["choices"] as? [[String: Any]], let first = choices.first, let text = first["text"] as? String {
                        completion(.success(text))
                        return
                    }
                    // Fallback: return raw string
                    if let raw = String(data: d, encoding: .utf8) {
                        completion(.success(raw))
                        return
                    }
                    completion(.failure(.decoding(NSError(domain: "GoutouAdapter", code: -1, userInfo: [NSLocalizedDescriptionKey: "No text field in response"]))))
                } else {
                    if let raw = String(data: d, encoding: .utf8) {
                        completion(.success(raw))
                        return
                    }
                    completion(.failure(.decoding(NSError(domain: "GoutouAdapter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format"]))))
                }
            } catch {
                completion(.failure(.decoding(error)))
            }
        }
        task.resume()
    }
}
