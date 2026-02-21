import ApplicationServices
import Foundation

final class AccessibilityTextService {
    static let shared = AccessibilityTextService()

    private init() {}

    func currentSelectedText() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        guard let focusedElement = focusedUIElement() else { return nil }

        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &value)
        guard status == .success else { return nil }

        if let text = value as? String {
            return text
        }

        if let attributed = value as? NSAttributedString {
            return attributed.string
        }

        return nil
    }

    private func focusedUIElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        guard status == .success, let focused else { return nil }
        guard CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(focused, to: AXUIElement.self)
    }
}
