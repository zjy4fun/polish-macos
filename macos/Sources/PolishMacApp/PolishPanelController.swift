import AppKit
import SwiftUI

@MainActor
final class PolishPanelController {
    private let resultPanelSize = NSSize(width: 760, height: 620)
    private let viewModel = ResultViewModel()
    private var window: NSPanel?
    private var onRepolish: ((String) -> Void)?

    func showLoading(original: String, anchorButton: NSStatusBarButton?, onRepolish: @escaping (String) -> Void) {
        self.onRepolish = onRepolish
        viewModel.canTriggerRepolish = true
        viewModel.original = original
        viewModel.simplified = ""
        viewModel.polished = ""
        viewModel.commitMessage = ""
        viewModel.errorMessage = nil
        viewModel.isLoading = true

        presentPanel(anchorButton: anchorButton)
    }

    func showResult(original: String, variants: PolishVariants, anchorButton: NSStatusBarButton?, onRepolish: @escaping (String) -> Void) {
        self.onRepolish = onRepolish
        viewModel.canTriggerRepolish = true
        viewModel.original = original
        viewModel.simplified = variants.simplified
        viewModel.polished = variants.polished
        viewModel.commitMessage = variants.commitMessage
        viewModel.errorMessage = nil
        viewModel.isLoading = false

        presentPanel(anchorButton: anchorButton)
    }

    func showError(original: String, message: String, anchorButton: NSStatusBarButton?, onRepolish: ((String) -> Void)? = nil) {
        self.onRepolish = onRepolish
        viewModel.canTriggerRepolish = onRepolish != nil
        viewModel.original = original
        viewModel.simplified = ""
        viewModel.polished = ""
        viewModel.commitMessage = ""
        viewModel.errorMessage = message
        viewModel.isLoading = false

        presentPanel(anchorButton: anchorButton)
    }

    private func presentPanel(anchorButton: NSStatusBarButton?) {
        let panel = ensurePanel()
        panel.setContentSize(resultPanelSize)
        position(panel: panel, below: anchorButton)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func ensurePanel() -> NSPanel {
        if let window {
            return window
        }

        let view = ResultView(
            viewModel: viewModel,
            onCopy: { value in
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(value, forType: .string)
            },
            onRepolish: { text in
                self.handleRepolish(text: text)
            },
            onClose: {
                self.window?.close()
            }
        )
        let host = NSHostingController(rootView: view)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: resultPanelSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "润色结果"
        panel.level = .floating
        panel.contentViewController = host
        panel.contentMinSize = resultPanelSize
        panel.setContentSize(resultPanelSize)
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace]

        self.window = panel
        return panel
    }

    private func handleRepolish(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            viewModel.errorMessage = "原文不能为空，请先输入内容再重新润色。"
            return
        }
        onRepolish?(trimmed)
    }

    private func position(panel: NSPanel, below anchorButton: NSStatusBarButton?) {
        guard let anchorButton, let anchorWindow = anchorButton.window else {
            panel.center()
            return
        }

        let buttonFrameInWindow = anchorButton.convert(anchorButton.bounds, to: nil)
        let buttonFrameOnScreen = anchorWindow.convertToScreen(buttonFrameInWindow)
        let screenFrame = (anchorWindow.screen ?? NSScreen.main)?.visibleFrame

        var originX = buttonFrameOnScreen.midX - panel.frame.width / 2
        var originY = buttonFrameOnScreen.minY - panel.frame.height - 8

        if let screenFrame {
            originX = min(max(originX, screenFrame.minX + 8), screenFrame.maxX - panel.frame.width - 8)
            originY = max(screenFrame.minY + 8, originY)
        }

        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }
}

@MainActor
final class ResultViewModel: ObservableObject {
    @Published var original: String = ""
    @Published var simplified: String = ""
    @Published var polished: String = ""
    @Published var commitMessage: String = ""
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var canTriggerRepolish: Bool = false

    var canRepolish: Bool {
        canTriggerRepolish &&
            original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
            !isLoading
    }
}

struct ResultView: View {
    @ObservedObject var viewModel: ResultViewModel
    let onCopy: (String) -> Void
    let onRepolish: (String) -> Void
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
            Text("原文（可编辑）")
                .font(.headline)
            TextEditor(text: $viewModel.original)
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: 95, maxHeight: 95, alignment: .leading)
                .border(Color.gray.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("重新润色") { onRepolish(viewModel.original) }
                    .disabled(!viewModel.canRepolish)
                Spacer()
                Button("复制原文") { onCopy(viewModel.original) }
            }

            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在润色，请稍候...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage = viewModel.errorMessage, errorMessage.isEmpty == false {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            outputSection(title: "简化版本", text: $viewModel.simplified, copyTitle: "复制简化版本")
            outputSection(title: "优化表述版本", text: $viewModel.polished, copyTitle: "复制优化版本")
            outputSection(title: "Commit Message", text: $viewModel.commitMessage, copyTitle: "复制 Commit Message")

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
