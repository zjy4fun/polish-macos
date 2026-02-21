import CryptoKit
import Foundation

final class PolishResultCache {
    private struct CacheStore: Codable {
        var entries: [String: PolishVariants]
        var order: [String]
    }

    private let storageKey = "polishResultCache.v1"
    private let maxEntries: Int
    private var entries: [String: PolishVariants] = [:]
    private var order: [String] = []

    init(maxEntries: Int = 120) {
        self.maxEntries = maxEntries
        load()
    }

    func get(text: String, settings: SettingsViewModel) -> PolishVariants? {
        let key = makeKey(text: text, settings: settings)
        guard let value = entries[key] else { return nil }
        touch(key: key)
        persist()
        return value
    }

    func set(text: String, settings: SettingsViewModel, variants: PolishVariants) {
        let key = makeKey(text: text, settings: settings)
        entries[key] = variants
        touch(key: key)
        trimIfNeeded()
        persist()
    }

    private func touch(key: String) {
        order.removeAll { $0 == key }
        order.append(key)
    }

    private func trimIfNeeded() {
        while order.count > maxEntries {
            let removed = order.removeFirst()
            entries.removeValue(forKey: removed)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        guard let decoded = try? JSONDecoder().decode(CacheStore.self, from: data) else { return }
        entries = decoded.entries
        order = decoded.order.filter { entries[$0] != nil }
    }

    private func persist() {
        let store = CacheStore(entries: entries, order: order)
        guard let data = try? JSONEncoder().encode(store) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func makeKey(text: String, settings: SettingsViewModel) -> String {
        let normalizedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        let providerSignature: String = {
            switch settings.provider {
            case .openAI:
                return "\(settings.providerID)|\(settings.endpoint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
            case .codex:
                return "\(settings.providerID)|\(settings.codexCommand.trimmingCharacters(in: .whitespacesAndNewlines))"
            case .claude:
                return "\(settings.providerID)|\(settings.claudeCommand.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
        }()

        let rawKey = "\(providerSignature)|\(normalizedText)"
        let digest = SHA256.hash(data: Data(rawKey.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
