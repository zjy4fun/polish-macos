import AppKit
import SwiftUI

@MainActor
final class PolishPanelController {
    private let resultPanelSize = NSSize(width: 760, height: 620)
    private var window: NSWindow?

    func showResult(original: String, variants: PolishVariants) {
        let view = ResultView(
            original: original,
            simplified: variants.simplified,
            polished: variants.polished,
            commitMessage: variants.commitMessage,
            onCopy: { value in
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(value, forType: .string)
            },
            onClose: {
                self.window?.close()
            }
        )
        show(view: AnyView(view), title: "润色结果", contentSize: resultPanelSize, minimumContentSize: resultPanelSize)
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

        show(view: AnyView(view), title: "错误", contentSize: NSSize(width: 420, height: 220), minimumContentSize: NSSize(width: 420, height: 220))
    }

    private func show(view: AnyView, title: String, contentSize: NSSize, minimumContentSize: NSSize) {
        let host = NSHostingController(rootView: view)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.level = .floating
        panel.contentViewController = host
        panel.contentMinSize = minimumContentSize
        panel.setContentSize(contentSize)
        panel.center()
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
    let onCopy: (String) -> Void
    let onClose: () -> Void

    private func outputSection(title: String, text: Binding<String>, copyTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            TextEditor(text: text)
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: 95, maxHeight: 95, alignment: .leading)
                .border(Color.gray.opacity(0.3))

            HStack {
                Spacer()
                Button(copyTitle) { onCopy(text.wrappedValue) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Button("复制原文") { onCopy(original) }
            }

            outputSection(title: "简化版本", text: $simplified, copyTitle: "复制简化版本")
            outputSection(title: "优化表述版本", text: $polished, copyTitle: "复制优化版本")
            outputSection(title: "Commit Message", text: $commitMessage, copyTitle: "复制 Commit Message")

            HStack {
                Spacer()
                Button("关闭", action: onClose)
            }
        }
        .padding(16)
        .frame(width: 760, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
