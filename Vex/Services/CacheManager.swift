import Foundation

/// 简单的内存 + UserDefaults 缓存管理器
actor CacheManager {
    static let shared = CacheManager()

    private var memoryCache: [String: CacheEntry] = [:]
    private let defaults = UserDefaults.standard
    private let cachePrefix = "vex_cache_"

    struct CacheEntry {
        let data: Data
        let timestamp: Date
    }

    // MARK: - Memory Cache

    func get<T: Codable>(_ key: String, type: T.Type, maxAge: TimeInterval = 300) -> T? {
        // Try memory first
        if let entry = memoryCache[key],
           Date().timeIntervalSince(entry.timestamp) < maxAge {
            return try? JSONDecoder().decode(CacheWrapper<T>.self, from: entry.data).value
        }

        // Try disk
        if let data = defaults.data(forKey: cachePrefix + key) {
            if let wrapper = try? JSONDecoder().decode(CacheWrapper<T>.self, from: data),
               Date().timeIntervalSince(wrapper.timestamp) < maxAge {
                // Warm up memory cache (使用相同格式的 data)
                memoryCache[key] = CacheEntry(data: data, timestamp: wrapper.timestamp)
                return wrapper.value
            }
        }

        return nil
    }

    func set<T: Codable>(_ key: String, value: T) {
        let now = Date()
        let wrapper = CacheWrapper(value: value, timestamp: now)
        if let data = try? JSONEncoder().encode(wrapper) {
            memoryCache[key] = CacheEntry(data: data, timestamp: now)
            defaults.set(data, forKey: cachePrefix + key)
        }
    }

    func remove(_ key: String) {
        memoryCache.removeValue(forKey: key)
        defaults.removeObject(forKey: cachePrefix + key)
    }

    func clearAll() {
        memoryCache.removeAll()
        let allKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(cachePrefix) }
        for key in allKeys {
            defaults.removeObject(forKey: key)
        }
    }
}

private struct CacheWrapper<T: Codable>: Codable {
    let value: T
    let timestamp: Date
}
