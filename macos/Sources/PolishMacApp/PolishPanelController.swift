import AppKit
import SwiftUI

@MainActor
final class PolishPanelController {
    private var window: NSWindow?

    func showResult(original: String, polished: String, onApply: @escaping (String) -> Void) {
        let view = ResultView(original: original, polished: polished, onApply: {
            onApply($0)
            self.window?.close()
        }, onClose: {
            self.window?.close()
        })
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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
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
    @State var polished: String
    let onApply: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("原文")
                .font(.headline)
            ScrollView {
                Text(original)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 80)

            Text("润色后")
                .font(.headline)
            TextEditor(text: $polished)
                .frame(height: 140)
                .font(.body)
                .border(Color.gray.opacity(0.3))

            HStack {
                Spacer()
                Button("取消", action: onClose)
                Button("替换选中文本") { onApply(polished) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
    }
}
