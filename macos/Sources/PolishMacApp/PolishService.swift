import Foundation

struct PolishVariants {
    let simplified: String
    let polished: String
    let commitMessage: String
}

final class PolishService {
    static let shared = PolishService()

    private init() {}

    func polishVariants(text: String, apiKey: String, endpoint: String) async throws -> PolishVariants {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw NSError(domain: "Polish", code: 1, userInfo: [NSLocalizedDescriptionKey: "选中文本为空"])
        }
        guard apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw NSError(domain: "Polish", code: 2, userInfo: [NSLocalizedDescriptionKey: "请先在设置中填写 OpenAI API Key"])
        }

        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "Polish", code: 3, userInfo: [NSLocalizedDescriptionKey: "API Endpoint 格式不合法"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let prompt = """
你是一个中文文本改写助手。请基于用户输入，输出以下 3 个字段：
1) simplified: 简化版本，保留原意，语句更短更直白
2) polished: 优化表述版本，更自然、清晰、专业
3) commit_message: 英文单行 git commit message（动词开头，<= 72 chars，no period）

只输出 JSON，不要输出任何额外文字。格式必须严格如下：
{
  "simplified": "...",
  "polished": "...",
  "commit_message": "..."
}
"""

        let payload = ChatRequest(
            model: "gpt-4.1",
            temperature: 0.4,
            maxTokens: 700,
            messages: [
                .init(role: "system", content: prompt),
                .init(role: "user", content: trimmed),
            ]
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "Polish", code: 4, userInfo: [NSLocalizedDescriptionKey: "网络响应异常"])
        }

        guard 200..<300 ~= http.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "Polish", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "请求失败：\(http.statusCode) \(body)"])
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines), content.isEmpty == false else {
            throw NSError(domain: "Polish", code: 5, userInfo: [NSLocalizedDescriptionKey: "模型未返回有效内容"])
        }

        let jsonText = extractJSON(from: content)
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw NSError(domain: "Polish", code: 6, userInfo: [NSLocalizedDescriptionKey: "模型返回内容无法解析"])
        }

        do {
            let result = try JSONDecoder().decode(VariantResponse.self, from: jsonData)
            return PolishVariants(
                simplified: result.simplified.trimmingCharacters(in: .whitespacesAndNewlines),
                polished: result.polished.trimmingCharacters(in: .whitespacesAndNewlines),
                commitMessage: result.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            throw NSError(domain: "Polish", code: 7, userInfo: [NSLocalizedDescriptionKey: "模型返回格式不正确，请重试"])
        }
    }

    private func extractJSON(from text: String) -> String {
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return text
    }
}

private struct VariantResponse: Decodable {
    let simplified: String
    let polished: String
    let commitMessage: String

    enum CodingKeys: String, CodingKey {
        case simplified
        case polished
        case commitMessage = "commit_message"
    }
}

struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let temperature: Double
    let maxTokens: Int
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model
        case temperature
        case maxTokens = "max_tokens"
        case messages
    }
}

struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}
