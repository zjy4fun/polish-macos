import AppKit
import SwiftUI

@MainActor
final class PolishPanelController {
    private let defaultResultPanelSize = NSSize(width: 640, height: 620)
    private let minimumResultPanelSize = NSSize(width: 540, height: 500)
    private let viewModel = ResultViewModel()
    private var window: NSPanel?
    private var onRepolish: ((String) -> Void)?
    private var hasPresentedContent = false

    func showPrepare(original: String, anchorButton: NSStatusBarButton?, onRepolish: @escaping (String) -> Void) {
        self.onRepolish = onRepolish
        hasPresentedContent = true
        viewModel.original = original
        viewModel.simplified = ""
        viewModel.polished = ""
        viewModel.commitMessage = ""
        viewModel.errorMessage = nil
        viewModel.isLoading = false

        presentPanel(anchorButton: anchorButton)
    }

    func showLoading(original: String, anchorButton: NSStatusBarButton?, onRepolish: @escaping (String) -> Void) {
        self.onRepolish = onRepolish
        hasPresentedContent = true
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
        guard let onRepolish else {
            viewModel.errorMessage = "当前无法开始润色，请重新按 ⌥⌘P。"
            return
        }
        onRepolish(trimmed)
    }

    private func position(panel: NSPanel, below anchorButton: NSStatusBarButton?) {
        guard let anchorButton, let anchorWindow = anchorButton.window else {
            panel.center()
            return
        }

        let buttonFrameInWindow = anchorButton.convert(anchorButton.bounds, to: nil)
        let buttonFrameOnScreen = anchorWindow.convertToScreen(buttonFrameInWindow)
        let screenFrame = (anchorWindow.screen ?? NSScreen.main)?.visibleFrame

        if let screenFrame {
            let fittingWidth = min(defaultResultPanelSize.width, max(minimumResultPanelSize.width, screenFrame.width - 16))
            let fittingHeight = min(defaultResultPanelSize.height, max(minimumResultPanelSize.height, screenFrame.height - 16))
            let currentSize = panel.contentLayoutRect.size
            if abs(currentSize.width - fittingWidth) > 0.5 || abs(currentSize.height - fittingHeight) > 0.5 {
                panel.setContentSize(NSSize(width: fittingWidth, height: fittingHeight))
            }
        }

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

    var canRepolish: Bool {
        original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && !isLoading
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
        return "编辑原文后，点击“开始润色”。"
    }

    private var statusColor: Color {
        if let errorMessage = viewModel.errorMessage, errorMessage.isEmpty == false {
            return .red
        }
        return .secondary
    }

    private var primaryActionTitle: String {
        hasOutput ? "重新润色" : "开始润色"
    }

    private var primaryActionSymbol: String {
        hasOutput ? "arrow.clockwise" : "sparkles"
    }

    var body: some View {
        ScrollView {
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
                            Label(primaryActionTitle, systemImage: primaryActionSymbol)
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
                        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 320, alignment: .topLeading)
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
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.visible)
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
            minWidth: 540,
            idealWidth: 640,
            maxWidth: .infinity,
            minHeight: 500,
            idealHeight: 620,
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
