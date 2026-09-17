import Foundation

/// Preferences that stay in memory, so tests never write to the user's preferences.
final class MemoryDefaults: UserDefaults {
    private var storage: [String: Any] = [:]
    override func object(forKey key: String) -> Any? { storage[key] }
    override func set(_ value: Any?, forKey key: String) { storage[key] = value }
    override func removeObject(forKey key: String) { storage.removeValue(forKey: key) }
}
