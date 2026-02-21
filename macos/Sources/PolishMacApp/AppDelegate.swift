import AppKit
import ApplicationServices
import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private let statusMenu = NSMenu()
    private var polishTask: Task<Void, Never>?
    private var latestPolishRequestID = UUID()
    private let resultCache = PolishResultCache()
    private let panelController = PolishPanelController()

    let viewModel = SettingsViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let appIcon = PolishBrandIcon.appIcon() {
            NSApp.applicationIconImage = appIcon
        }
        requestAccessibilityPermissionIfNeeded()
        installStatusItem()
        registerHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        polishTask?.cancel()
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let hotKeyHandler {
            RemoveEventHandler(hotKeyHandler)
        }
    }

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let statusItem else { return }

        if let button = statusItem.button {
            let icon = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Polish")
            icon?.isTemplate = true
            button.image = icon
            button.imagePosition = .imageOnly
            button.toolTip = "Polish"
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let settingsItem = NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        statusMenu.addItem(settingsItem)
        statusMenu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            NSMenu.popUpContextMenu(statusMenu, with: event, for: sender)
            return
        }

        if panelController.restoreLastPanel(anchorButton: sender) {
            return
        }

        let onRepolish: (String) -> Void = { [weak self] editedText in
            self?.runPolish(text: editedText)
        }
        panelController.showError(
            original: "",
            message: "暂无润色结果，请先选中文本后按 ⌥⌘P。",
            anchorButton: sender,
            onRepolish: onRepolish
        )
    }

    @objc private func openSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func makeSettingsWindow() -> NSWindow {
        let hosting = NSHostingController(
            rootView: SettingsView(viewModel: viewModel)
                .frame(width: 560, height: 420)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 560, height: 420))
        return window
    }

    private func requestAccessibilityPermissionIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let callback: EventHandlerUPP = { _, eventRef, userData in
            guard let eventRef, let userData else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if hotKeyID.id == 1 {
                delegate.handlePolishShortcut()
            }
            return noErr
        }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &eventType, selfPointer, &hotKeyHandler)

        let cmdOptionKey = UInt32(cmdKey | optionKey)
        let hotKeyID = EventHotKeyID(signature: OSType("POLI".fourCharCodeValue), id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_P), cmdOptionKey, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
    }

    private func handlePolishShortcut() {
        let onRepolish: (String) -> Void = { [weak self] editedText in
            self?.runPolish(text: editedText)
        }
        let textService = AccessibilityTextService.shared
        guard let selectedText = textService.currentSelectedText()?.trimmingCharacters(in: .whitespacesAndNewlines),
              selectedText.isEmpty == false else {
            panelController.showError(
                original: "",
                message: "未检测到选中文本。请先选中文本后再按 ⌥⌘P，并确认已在系统设置中授予辅助功能权限。",
                anchorButton: statusItem?.button,
                onRepolish: onRepolish
            )
            return
        }

        guard viewModel.isConfigured else {
            openSettings()
            panelController.showError(
                original: selectedText,
                message: "当前 Provider 尚未完成配置，请先在设置里完成引导。",
                anchorButton: statusItem?.button,
                onRepolish: onRepolish
            )
            return
        }

        panelController.showPrepare(
            original: selectedText,
            anchorButton: statusItem?.button,
            onRepolish: onRepolish
        )
    }

    private func runPolish(text: String) {
        let onRepolish: (String) -> Void = { [weak self] editedText in
            self?.runPolish(text: editedText)
        }
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedText.isEmpty == false else {
            panelController.showError(
                original: text,
                message: "原文不能为空，请先输入内容后再润色。",
                anchorButton: statusItem?.button,
                onRepolish: onRepolish
            )
            return
        }

        guard viewModel.isConfigured else {
            openSettings()
            panelController.showError(
                original: text,
                message: "当前 Provider 尚未完成配置，请先在设置里完成引导。",
                anchorButton: statusItem?.button,
                onRepolish: onRepolish
            )
            return
        }

        let requestID = UUID()
        latestPolishRequestID = requestID
        polishTask?.cancel()

        if let cached = resultCache.get(text: normalizedText, settings: viewModel) {
            panelController.showResult(
                original: text,
                variants: cached,
                anchorButton: statusItem?.button,
                onRepolish: onRepolish
            )
            return
        }

        panelController.showLoading(original: text, anchorButton: statusItem?.button, onRepolish: onRepolish)

        polishTask = Task { @MainActor in
            do {
                let variants = try await PolishService.shared.polishVariants(text: text, settings: viewModel)
                guard Task.isCancelled == false, latestPolishRequestID == requestID else { return }
                resultCache.set(text: normalizedText, settings: viewModel, variants: variants)
                panelController.showResult(
                    original: text,
                    variants: variants,
                    anchorButton: statusItem?.button,
                    onRepolish: onRepolish
                )
            } catch {
                guard Task.isCancelled == false, latestPolishRequestID == requestID else { return }
                if error is CancellationError { return }
                panelController.showError(
                    original: text,
                    message: error.localizedDescription,
                    anchorButton: statusItem?.button,
                    onRepolish: onRepolish
                )
            }
        }
    }
}

private extension String {
    var fourCharCodeValue: FourCharCode {
        utf16.reduce(0) { $0 << 8 + FourCharCode($1) }
    }
}
