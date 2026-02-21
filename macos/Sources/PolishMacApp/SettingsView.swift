import SwiftUI

final class SettingsViewModel: ObservableObject {
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "apiKey") }
    }
    @Published var endpoint: String {
        didSet { UserDefaults.standard.set(endpoint, forKey: "endpoint") }
    }
    @Published var selectedStyleID: String {
        didSet { UserDefaults.standard.set(selectedStyleID, forKey: "styleID") }
    }

    var selectedStyle: PolishStyle {
        PolishStyle.presets.first(where: { $0.id == selectedStyleID }) ?? PolishStyle.presets[0]
    }

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.endpoint = UserDefaults.standard.string(forKey: "endpoint") ?? "https://api.openai.com/v1/chat/completions"
        self.selectedStyleID = UserDefaults.standard.string(forKey: "styleID") ?? "formal"
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            SecureField("OpenAI API Key", text: $viewModel.apiKey)
            TextField("API Endpoint", text: $viewModel.endpoint)
            Picker("默认润色风格", selection: $viewModel.selectedStyleID) {
                ForEach(PolishStyle.presets) { style in
                    Text(style.name).tag(style.id)
                }
            }
            Text("全局快捷键：⌘P（先在任意 App 中选中文本）")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("首次使用需在系统设置中授予辅助功能权限。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
