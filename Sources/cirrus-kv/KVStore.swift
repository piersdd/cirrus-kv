import Foundation

/// Wrapper around NSUbiquitousKeyValueStore with sync and error handling.
/// All operations are synchronous from the CLI's perspective.
final class KVStore: @unchecked Sendable {
    static let shared = KVStore()

    private let store = NSUbiquitousKeyValueStore.default

    private init() {}

    // MARK: - Core operations

    func get(_ key: String) -> String? {
        store.synchronize()
        return store.string(forKey: key)
    }

    func getJSON(_ key: String) -> Any? {
        store.synchronize()
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    func set(_ key: String, value: String) -> Bool {
        guard checkQuota() else { return false }
        store.set(value, forKey: key)
        store.synchronize()
        return true
    }

    func setJSON(_ key: String, jsonString: String) -> Bool {
        guard checkQuota() else { return false }
        guard let data = jsonString.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: data) else {
            fputs("error: invalid JSON\n", stderr)
            return false
        }
        store.set(data, forKey: key)
        store.synchronize()
        return true
    }

    func delete(_ key: String) {
        store.removeObject(forKey: key)
        store.synchronize()
    }

    func sync() {
        store.synchronize()
    }

    // MARK: - Listing

    func listKeys(prefix: String? = nil) -> [String] {
        store.synchronize()
        let all = store.dictionaryRepresentation
        var keys = Array(all.keys).sorted()
        if let prefix = prefix {
            keys = keys.filter { $0.hasPrefix(prefix) }
        }
        return keys
    }

    // MARK: - Budget

    struct Budget {
        let keyCount: Int
        let estimatedBytes: Int
        let maxKeys: Int
        let maxBytes: Int

        var keyPct: Double { Double(keyCount) / Double(maxKeys) * 100.0 }
        var bytePct: Double { Double(estimatedBytes) / Double(maxBytes) * 100.0 }
    }

    func budget() -> Budget {
        store.synchronize()
        let dict = store.dictionaryRepresentation
        let keyCount = dict.count

        // Estimate byte usage: serialize all values
        var totalBytes = 0
        for (key, value) in dict {
            totalBytes += key.utf8.count
            if let s = value as? String {
                totalBytes += s.utf8.count
            } else if let d = value as? Data {
                totalBytes += d.count
            } else if value is NSNumber {
                totalBytes += 8 // numeric types
            } else {
                // Fallback: try to serialize
                if let data = try? NSKeyedArchiver.archivedData(
                    withRootObject: value, requiringSecureCoding: false
                ) {
                    totalBytes += data.count
                }
            }
        }

        return Budget(
            keyCount: keyCount,
            estimatedBytes: totalBytes,
            maxKeys: 1024,
            maxBytes: 1_048_576  // 1 MB
        )
    }

    // MARK: - Watch

    /// Block until the value for `key` changes or timeout (seconds) elapses.
    /// Returns the new value, or nil on timeout.
    func watch(key: String, timeout: TimeInterval) -> String? {
        store.synchronize()
        let initialValue = store.string(forKey: key)
        let deadline = Date().addingTimeInterval(timeout)

        // Poll every 0.5s — iCloud KV change notifications require a RunLoop
        // which is fine since we're a CLI blocking on this call.
        while Date() < deadline {
            store.synchronize()
            let current = store.string(forKey: key)
            if current != initialValue {
                return current
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return nil  // timeout
    }

    // MARK: - Private

    private func checkQuota() -> Bool {
        let b = budget()
        if b.keyCount >= b.maxKeys {
            fputs("error: key count quota exceeded (\(b.keyCount)/\(b.maxKeys))\n", stderr)
            return false
        }
        if b.estimatedBytes >= b.maxBytes {
            fputs("error: storage quota exceeded (\(b.estimatedBytes)/\(b.maxBytes) bytes)\n", stderr)
            return false
        }
        return true
    }
}
