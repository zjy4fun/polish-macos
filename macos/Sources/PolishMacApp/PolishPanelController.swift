import AppKit
import SwiftUI

@MainActor
final class PolishPanelController {
    private let defaultResultPanelSize = NSSize(width: 640, height: 500)
    private let minimumResultPanelSize = NSSize(width: 580, height: 440)
    private let viewModel = ResultViewModel()
    private var window: NSPanel?
    private var onRepolish: ((String) -> Void)?
    private var hasPresentedContent = false

    func showLoading(original: String, anchorButton: NSStatusBarButton?, onRepolish: @escaping (String) -> Void) {
        self.onRepolish = onRepolish
        hasPresentedContent = true
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
        hasPresentedContent = true
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
        hasPresentedContent = true
        viewModel.canTriggerRepolish = onRepolish != nil
        viewModel.original = original
        viewModel.simplified = ""
        viewModel.polished = ""
        viewModel.commitMessage = ""
        viewModel.errorMessage = message
        viewModel.isLoading = false

        presentPanel(anchorButton: anchorButton)
    }

    @discardableResult
    func restoreLastPanel(anchorButton: NSStatusBarButton?) -> Bool {
        guard hasPresentedContent else { return false }
        presentPanel(anchorButton: anchorButton)
        return true
    }

    private func presentPanel(anchorButton: NSStatusBarButton?) {
        let panel = ensurePanel()
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
            contentRect: NSRect(origin: .zero, size: defaultResultPanelSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "润色结果"
        panel.level = .floating
        panel.contentViewController = host
        panel.contentMinSize = minimumResultPanelSize
        panel.setContentSize(defaultResultPanelSize)
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
    @State private var selectedOutput: OutputKind = .simplified

    private enum OutputKind: String, CaseIterable, Identifiable {
        case simplified
        case polished
        case commitMessage

        var id: Self { self }

        var title: String {
            switch self {
            case .simplified: return "简化版本"
            case .polished: return "优化版本"
            case .commitMessage: return "Commit Message"
            }
        }

        var copyTitle: String {
            switch self {
            case .simplified: return "复制简化版本"
            case .polished: return "复制优化版本"
            case .commitMessage: return "复制 Commit Message"
            }
        }

        var emptyHint: String {
            switch self {
            case .simplified: return "简化版本会展示在这里。"
            case .polished: return "优化版本会展示在这里。"
            case .commitMessage: return "Commit Message 会展示在这里。"
            }
        }
    }

    private var selectedOutputText: Binding<String> {
        switch selectedOutput {
        case .simplified:
            return $viewModel.simplified
        case .polished:
            return $viewModel.polished
        case .commitMessage:
            return $viewModel.commitMessage
        }
    }

    private var selectedOutputValue: String {
        selectedOutputText.wrappedValue
    }

    private var hasOutput: Bool {
        [viewModel.simplified, viewModel.polished, viewModel.commitMessage]
            .contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
    }

    private var statusMessage: String {
        if viewModel.isLoading {
            return "正在润色，请稍候..."
        }
        if let errorMessage = viewModel.errorMessage, errorMessage.isEmpty == false {
            return errorMessage
        }
        if hasOutput {
            return "可切换分段查看并复制结果。"
        }
        return selectedOutput.emptyHint
    }

    private var statusColor: Color {
        if let errorMessage = viewModel.errorMessage, errorMessage.isEmpty == false {
            return .red
        }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("润色结果", systemImage: "wand.and.stars")
                    .font(.headline.weight(.semibold))
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 10) {
                Label("原文（可编辑）", systemImage: "doc.text")
                    .font(.subheadline.weight(.semibold))

                TextEditor(text: $viewModel.original)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .padding(8)
                    .frame(maxWidth: .infinity, minHeight: 88, maxHeight: 118, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.gray.opacity(0.18), lineWidth: 1)
                    )

                HStack(spacing: 10) {
                    Button {
                        onRepolish(viewModel.original)
                    } label: {
                        Label("重新润色", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canRepolish)

                    Button("复制原文") { onCopy(viewModel.original) }
                        .disabled(viewModel.original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                    Button("关闭", action: onClose)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            VStack(alignment: .leading, spacing: 10) {
                Label("润色输出", systemImage: "text.alignleft")
                    .font(.subheadline.weight(.semibold))

                Picker("输出类型", selection: $selectedOutput) {
                    ForEach(OutputKind.allCases) { output in
                        Text(output.title).tag(output)
                    }
                }
                .pickerStyle(.segmented)

                TextEditor(text: selectedOutputText)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .padding(8)
                    .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.gray.opacity(0.18), lineWidth: 1)
                    )

                HStack {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(statusColor)
                        .lineLimit(2)
                    Spacer()
                    Button(selectedOutput.copyTitle) { onCopy(selectedOutputValue) }
                        .disabled(selectedOutputValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .frame(
            minWidth: 600,
            idealWidth: 640,
            maxWidth: .infinity,
            minHeight: 460,
            idealHeight: 500,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .onChange(of: viewModel.isLoading) { isLoading in
            if isLoading {
                selectedOutput = .simplified
            }
        }
    }
}
