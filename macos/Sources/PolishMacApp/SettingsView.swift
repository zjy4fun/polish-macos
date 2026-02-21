import SwiftUI

enum PolishProvider: String, CaseIterable, Identifiable {
    case openAI = "openai"
    case codex = "codex"
    case claude = "claude"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .openAI: return "OpenAI API"
        case .codex: return "本地 Codex CLI"
        case .claude: return "本地 Claude Code CLI"
        }
    }
}

final class SettingsViewModel: ObservableObject {
    @Published var providerID: String {
        didSet { UserDefaults.standard.set(providerID, forKey: "providerID") }
    }
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "apiKey") }
    }
    @Published var endpoint: String {
        didSet { UserDefaults.standard.set(endpoint, forKey: "endpoint") }
    }
    @Published var codexCommand: String {
        didSet { UserDefaults.standard.set(codexCommand, forKey: "codexCommand") }
    }
    @Published var claudeCommand: String {
        didSet { UserDefaults.standard.set(claudeCommand, forKey: "claudeCommand") }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    var provider: PolishProvider {
        PolishProvider(rawValue: providerID) ?? .codex
    }

    init() {
        self.providerID = UserDefaults.standard.string(forKey: "providerID") ?? PolishProvider.codex.rawValue
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.endpoint = UserDefaults.standard.string(forKey: "endpoint") ?? "https://api.openai.com/v1/chat/completions"

        let savedCodexCommand = UserDefaults.standard.string(forKey: "codexCommand")
        let resolvedCodexCommand: String
        if let savedCodexCommand, savedCodexCommand == "codex exec {{prompt}}" {
            resolvedCodexCommand = "codex exec --skip-git-repo-check {{prompt}}"
            UserDefaults.standard.set(resolvedCodexCommand, forKey: "codexCommand")
        } else {
            resolvedCodexCommand = savedCodexCommand ?? "codex exec --skip-git-repo-check {{prompt}}"
        }
        self.codexCommand = resolvedCodexCommand

        self.claudeCommand = UserDefaults.standard.string(forKey: "claudeCommand") ?? "claude -p {{prompt}}"
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    var isConfigured: Bool {
        switch provider {
        case .openAI:
            return apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
                endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .codex:
            return codexCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .claude:
            return claudeCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showOnboarding = false

    var body: some View {
        Form {
            Section("模型来源") {
                Picker("Provider", selection: $viewModel.providerID) {
                    ForEach(PolishProvider.allCases) { provider in
                        Text(provider.name).tag(provider.rawValue)
                    }
                }
            }

            switch viewModel.provider {
            case .openAI:
                Section("OpenAI 配置") {
                    SecureField("OpenAI API Key", text: $viewModel.apiKey)
                    TextField("API Endpoint", text: $viewModel.endpoint)
                }
            case .codex:
                Section("Codex CLI 配置") {
                    TextField("命令模板", text: $viewModel.codexCommand)
                    Text("示例：codex exec --skip-git-repo-check {{prompt}}")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            case .claude:
                Section("Claude Code CLI 配置") {
                    TextField("命令模板", text: $viewModel.claudeCommand)
                    Text("示例：claude -p {{prompt}}")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("使用说明") {
                Text("全局快捷键：⌥⌘P（读取当前选中的文本）")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("按下后先进入确认编辑，再点击“开始润色”。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("完成后会生成：简化版本 + 优化表述版本 + commit message")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("结果弹窗支持一键复制各版本到剪切板。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("重新打开引导设置") { showOnboarding = true }
            }
        }
        .padding()
        .onAppear {
            showOnboarding = !viewModel.hasCompletedOnboarding
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(viewModel: viewModel, isPresented: $showOnboarding)
        }
    }
}

struct OnboardingView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("欢迎使用 PolishMac")
                .font(.title2).bold()

            Text("先完成一次引导设置：选择模型来源并填写必要配置。")
                .foregroundStyle(.secondary)

            Picker("Provider", selection: $viewModel.providerID) {
                ForEach(PolishProvider.allCases) { provider in
                    Text(provider.name).tag(provider.rawValue)
                }
            }

            if viewModel.provider == .openAI {
                SecureField("OpenAI API Key", text: $viewModel.apiKey)
                TextField("API Endpoint", text: $viewModel.endpoint)
            } else if viewModel.provider == .codex {
                TextField("Codex 命令模板", text: $viewModel.codexCommand)
                Text("默认：codex exec --skip-git-repo-check {{prompt}}")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                TextField("Claude 命令模板", text: $viewModel.claudeCommand)
                Text("默认：claude -p {{prompt}}")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("稍后") { isPresented = false }
                Button("完成") {
                    viewModel.hasCompletedOnboarding = true
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.isConfigured)
            }
        }
        .padding(20)
        .frame(width: 560)
    }
}
