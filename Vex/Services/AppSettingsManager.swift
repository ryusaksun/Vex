import Foundation
import SwiftUI

@MainActor
final class AppSettingsManager: ObservableObject {
    @AppStorage("show_avatar") var showAvatar: Bool = true
    @AppStorage("show_last_reply") var showLastReply: Bool = true
    @AppStorage("open_links_in_app") var openLinksInApp: Bool = true
    @AppStorage("haptic_feedback") var hapticFeedback: Bool = true
    @AppStorage("auto_check_clipboard") var autoCheckClipboard: Bool = true
    @AppStorage("configured_home_tabs") private var configuredHomeTabsJSON: String = ""
    @AppStorage("home_tab_values") private var legacyHomeTabValuesJSON: String = ""

    // 图床配置
    @AppStorage("imgur_client_id") var imgurClientId: String = ""

    var imageUploadConfig: ImageUploader.Config {
        ImageUploader.Config(clientId: imgurClientId)
    }

    var isImageUploadConfigured: Bool {
        imageUploadConfig.isValid
    }

    private var configuredStoredHomeTabs: [HomeTabOption] {
        get {
            guard let data = configuredHomeTabsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([HomeTabOption].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                configuredHomeTabsJSON = ""
                return
            }
            configuredHomeTabsJSON = json
        }
    }

    private var legacyConfiguredHomeTabValues: [String] {
        guard let data = legacyHomeTabValuesJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }

    var fallbackHomeTabs: [HomeTabOption] {
        mergedHomeTabs([
            HomeTabOption(value: "tech", label: "技术"),
            HomeTabOption(value: "creative", label: "创意"),
            HomeTabOption(value: "play", label: "好玩"),
            HomeTabOption(value: "apple", label: "Apple"),
            HomeTabOption(value: "jobs", label: "酷工作"),
            HomeTabOption(value: "deals", label: "交易"),
            HomeTabOption(value: "city", label: "城市"),
            HomeTabOption(value: "qna", label: "问与答"),
            HomeTabOption(value: "hot", label: "最热"),
            HomeTabOption(value: "all", label: "全部"),
            HomeTabOption(value: "r2", label: "R2"),
            HomeTabOption(value: "xna", label: "VXNA", type: .xna)
        ])
    }

    func mergedHomeTabs(_ tabs: [HomeTabOption]) -> [HomeTabOption] {
        var result: [HomeTabOption] = []
        var seen = Set<String>()

        for tab in tabs where seen.insert(tab.storageKey).inserted {
            result.append(tab)
        }

        if !seen.contains(HomeTabOption(value: "recent", label: "最近").storageKey) {
            let recent = HomeTabOption(value: "recent", label: "最近")
            if let allIndex = result.firstIndex(where: { $0.value == "all" }) {
                result.insert(recent, at: allIndex + 1)
            } else {
                result.insert(recent, at: 0)
            }
        }

        return result
    }

    func configuredHomeTabs(from availableTabs: [HomeTabOption]) -> [HomeTabOption] {
        let mergedTabs = mergedHomeTabs(availableTabs)
        let byStorageKey = Dictionary(uniqueKeysWithValues: mergedTabs.map { ($0.storageKey, $0) })

        if !configuredStoredHomeTabs.isEmpty {
            var seen = Set<String>()
            let orderedTabs = configuredStoredHomeTabs.compactMap { tab -> HomeTabOption? in
                let resolved = byStorageKey[tab.storageKey] ?? tab
                guard seen.insert(resolved.storageKey).inserted else { return nil }
                return resolved
            }
            return orderedTabs.isEmpty ? mergedTabs : orderedTabs
        }

        let legacyValues = legacyConfiguredHomeTabValues
        guard !legacyValues.isEmpty else { return mergedTabs }

        let orderedTabs = legacyValues.compactMap { legacyValue in
            mergedTabs.first { $0.value == legacyValue }
        }
        return orderedTabs.isEmpty ? mergedTabs : orderedTabs
    }

    func saveConfiguredHomeTabs(_ tabs: [HomeTabOption]) {
        configuredStoredHomeTabs = tabs
        legacyHomeTabValuesJSON = ""
    }

    func resetConfiguredHomeTabs() {
        configuredStoredHomeTabs = []
        legacyHomeTabValuesJSON = ""
    }
}
