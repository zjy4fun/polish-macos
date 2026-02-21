import AppKit
import Carbon
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private let panelController = PolishPanelController()

    let viewModel = SettingsViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        requestAccessibilityPermissionIfNeeded()
        installStatusItem()
        registerHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let hotKeyHandler {
            RemoveEventHandler(hotKeyHandler)
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Polish"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
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

        let cmdKeyOnly = UInt32(cmdKey)
        let hotKeyID = EventHotKeyID(signature: OSType("POLI".fourCharCodeValue), id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_P), cmdKeyOnly, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
    }

    private func handlePolishShortcut() {
        Task { @MainActor in
            let textService = AccessibilityTextService.shared
            guard let selectedText = textService.currentSelectedText(), selectedText.isEmpty == false else {
                panelController.showError("未检测到选中文本，请先选中文本后再按 ⌘P")
                return
            }

            do {
                let polished = try await PolishService.shared.polish(text: selectedText, apiKey: viewModel.apiKey, endpoint: viewModel.endpoint, stylePrompt: viewModel.selectedStyle.prompt)
                panelController.showResult(original: selectedText, polished: polished) { replacement in
                    textService.replaceCurrentSelection(with: replacement)
                }
            } catch {
                panelController.showError(error.localizedDescription)
            }
        }
    }
}

private extension String {
    var fourCharCodeValue: FourCharCode {
        utf16.reduce(0) { $0 << 8 + FourCharCode($1) }
    }
}
