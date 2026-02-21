import Foundation

struct PolishVariants {
    let simplified: String
    let polished: String
    let commitMessage: String
}

final class PolishService {
    static let shared = PolishService()

    private init() {}

    func polishVariants(text: String, settings: SettingsViewModel) async throws -> PolishVariants {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw NSError(domain: "Polish", code: 1, userInfo: [NSLocalizedDescriptionKey: "剪切板文本为空"])
        }

        switch settings.provider {
        case .openAI:
            return try await polishWithOpenAI(text: trimmed, apiKey: settings.apiKey, endpoint: settings.endpoint)
        case .codex:
            return try await polishWithLocalCLI(text: trimmed, commandTemplate: settings.codexCommand, cliName: "Codex")
        case .claude:
            return try await polishWithLocalCLI(text: trimmed, commandTemplate: settings.claudeCommand, cliName: "Claude")
        }
    }

    private func polishWithOpenAI(text: String, apiKey: String, endpoint: String) async throws -> PolishVariants {
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
            temperature: 0.4,
            maxTokens: 700,
            messages: [
                .init(role: "system", content: structuredPrompt),
                .init(role: "user", content: text),
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

        return try parseVariants(from: content)
    }

    private func polishWithLocalCLI(text: String, commandTemplate: String, cliName: String) async throws -> PolishVariants {
        let template = commandTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard template.isEmpty == false else {
            throw NSError(domain: "Polish", code: 10, userInfo: [NSLocalizedDescriptionKey: "请先在设置中填写 \(cliName) 命令模板"])
        }

        let fullPrompt = "\(structuredPrompt)\n\n用户输入：\n\(text)"
        let escaped = shellEscape(fullPrompt)
        let command = template.contains("{{prompt}}")
            ? template.replacingOccurrences(of: "{{prompt}}", with: escaped)
            : "\(template) \(escaped)"

        let output = try await runShellCommand(command)
        guard output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw NSError(domain: "Polish", code: 11, userInfo: [NSLocalizedDescriptionKey: "\(cliName) 未返回内容，请检查命令模板"])
        }

        return try parseVariants(from: output)
    }

    private func parseVariants(from rawText: String) throws -> PolishVariants {
        let jsonText = extractJSON(from: rawText)
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

    private func runShellCommand(_ command: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { p in
                let outData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let out = String(data: outData, encoding: .utf8) ?? ""
                let err = String(data: errData, encoding: .utf8) ?? ""

                if p.terminationStatus == 0 {
                    continuation.resume(returning: out)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "Polish",
                        code: Int(p.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: "本地命令执行失败：\n\(err.isEmpty ? out : err)"]
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: NSError(domain: "Polish", code: 12, userInfo: [NSLocalizedDescriptionKey: "无法启动本地命令：\(error.localizedDescription)"]))
            }
        }
    }

    private func shellEscape(_ text: String) -> String {
        return "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func extractJSON(from text: String) -> String {
        if let fencedStart = text.range(of: "```json") {
            let tail = text[fencedStart.upperBound...]
            if let fencedEnd = tail.range(of: "```") {
                return String(tail[..<fencedEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return text
    }

    private var structuredPrompt: String {
        """
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
