import SwiftUI

final class SettingsViewModel: ObservableObject {
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "apiKey") }
    }
    @Published var endpoint: String {
        didSet { UserDefaults.standard.set(endpoint, forKey: "endpoint") }
    }

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.endpoint = UserDefaults.standard.string(forKey: "endpoint") ?? "https://api.openai.com/v1/chat/completions"
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            SecureField("OpenAI API Key", text: $viewModel.apiKey)
            TextField("API Endpoint", text: $viewModel.endpoint)
            Text("全局快捷键：⌘P（直接读取剪切板中的文本）")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("按下后会同时生成：原文 + 简化版本 + 优化表述版本 + commit message")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("结果弹窗支持一键复制各版本到剪切板。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
