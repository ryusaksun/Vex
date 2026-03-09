import SwiftUI

@main
struct VexApp: App {
    @State private var authManager = AuthManager()
    @State private var viewedTopics = ViewedTopicsManager()
    @State private var alertManager = AlertManager()
    @State private var router = Router()
    @State private var cloudflareManager = CloudflareManager()
    @State private var clipboardWatcher = ClipboardWatcher()
    @State private var favoriteNodesManager = FavoriteNodesManager()

    @StateObject private var themeManager = ThemeManager()
    @StateObject private var appSettings = AppSettingsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(viewedTopics)
                .environment(alertManager)
                .environment(router)
                .environment(cloudflareManager)
                .environment(clipboardWatcher)
                .environment(favoriteNodesManager)
                .environmentObject(themeManager)
                .environmentObject(appSettings)
                .preferredColorScheme(themeManager.colorScheme)
                .tint(themeManager.accentColor)
                .task {
                    await authManager.checkAuth()
                }
                .onChange(of: cloudflareManager.needsVerification) {
                    // Cloudflare 验证完成后重新检查认证状态
                    if !cloudflareManager.needsVerification {
                        Task { await authManager.checkAuth(forceRefresh: true) }
                    }
                }
                .onOpenURL { url in
                    DeepLinkHandler.handle(url: url, router: router)
                }
        }
    }
}
