import Foundation

struct PolishStyle: Identifiable, Hashable {
    let id: String
    let name: String
    let prompt: String

    static let presets: [PolishStyle] = [
        .init(id: "formal", name: "正式", prompt: "你是一个专业文本润色专家。请将用户提供的内容改写为正式、得体、逻辑清晰的表达。只返回润色后的文本。"),
        .init(id: "concise", name: "简洁", prompt: "你是一个精简文案专家。请将用户提供的内容精简为更简洁有力的表达，保留核心意思。只返回润色后的文本。"),
        .init(id: "commit", name: "Commit 优化", prompt: "你是一个 Git 提交信息优化专家。请改写为简洁清晰的 commit message。只返回单行 commit message。"),
    ]
}

final class PolishService {
    static let shared = PolishService()

    private init() {}

    func polish(text: String, apiKey: String, endpoint: String, stylePrompt: String) async throws -> String {
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

        let payload = ChatRequest(
            model: "gpt-4.1",
            temperature: 0.7,
            maxTokens: 600,
            messages: [
                .init(role: "system", content: stylePrompt),
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
        if let content = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines), content.isEmpty == false {
            return content
        }

        throw NSError(domain: "Polish", code: 5, userInfo: [NSLocalizedDescriptionKey: "模型未返回有效内容"])
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
