import ApplicationServices
import Foundation

final class AccessibilityTextService {
    static let shared = AccessibilityTextService()

    private init() {}

    func currentSelectedText() -> String? {
        guard let focusedElement = focusedUIElement() else { return nil }

        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &value)
        guard status == .success else { return nil }

        return value as? String
    }

    func replaceCurrentSelection(with text: String) {
        guard let focusedElement = focusedUIElement() else { return }
        AXUIElementSetAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
    }

    private func focusedUIElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        guard status == .success else { return nil }
        return focused as? AXUIElement
    }
}
