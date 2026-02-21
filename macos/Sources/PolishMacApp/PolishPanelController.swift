import AppKit
import SwiftUI

@MainActor
final class PolishPanelController {
    private var window: NSWindow?

    func showResult(original: String, variants: PolishVariants, onApply: @escaping (String) -> Void) {
        let view = ResultView(
            original: original,
            simplified: variants.simplified,
            polished: variants.polished,
            commitMessage: variants.commitMessage,
            onApply: {
                onApply($0)
                self.window?.close()
            },
            onClose: {
                self.window?.close()
            }
        )
        show(view: AnyView(view), title: "润色结果")
    }

    func showError(_ message: String) {
        let view = VStack(alignment: .leading, spacing: 12) {
            Text("润色失败")
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
            Button("关闭") { self.window?.close() }
        }
        .padding(20)
        .frame(width: 420)

        show(view: AnyView(view), title: "错误")
    }

    private func show(view: AnyView, title: String) {
        let host = NSHostingController(rootView: view)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 620),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.level = .floating
        panel.center()
        panel.contentViewController = host
        panel.isReleasedWhenClosed = false
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = panel
    }
}

struct ResultView: View {
    let original: String
    @State var simplified: String
    @State var polished: String
    @State var commitMessage: String
    let onApply: (String) -> Void
    let onClose: () -> Void

    private func outputSection(title: String, text: Binding<String>, applyTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            TextEditor(text: text)
                .frame(height: 95)
                .font(.body)
                .border(Color.gray.opacity(0.3))

            HStack {
                Spacer()
                Button(applyTitle) { onApply(text.wrappedValue) }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("原文")
                .font(.headline)
            ScrollView {
                Text(original)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 90)

            outputSection(title: "简化版本", text: $simplified, applyTitle: "替换为简化版本")
            outputSection(title: "优化表述版本", text: $polished, applyTitle: "替换为优化版本")
            outputSection(title: "Commit Message", text: $commitMessage, applyTitle: "替换为 Commit Message")

            HStack {
                Spacer()
                Button("关闭", action: onClose)
            }
        }
        .padding(16)
    }
}
