import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(Router.self) private var router
    @Environment(CloudflareManager.self) private var cloudflare
    @Environment(ClipboardWatcher.self) private var clipboard
    @EnvironmentObject private var settings: AppSettingsManager
    @EnvironmentObject private var theme: ThemeManager

    @State private var showNewTopic = false
    @State private var browserDestination: BrowserDestination?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                SidebarView()
            } else {
                tabView
            }
        }
        .toastOverlay()
        .sheet(isPresented: $showNewTopic) {
            NewTopicView()
        }
        .sheet(item: $browserDestination) { destination in
            NavigationStack {
                InAppBrowserView(url: destination.url)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") {
                                browserDestination = nil
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: Binding(
            get: { cloudflare.needsVerification },
            set: { if !$0 { cloudflare.verificationCompleted() } }
        )) {
            NavigationStack {
                CloudflareWebView {
                    cloudflare.verificationCompleted()
                }
                .onAppear {
                    cloudflare.startVerification()
                }
                .navigationTitle("验证")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            cloudflare.verificationCompleted()
                        }
                    }
                }
            }
        }
        .alert("检测到 V2EX 链接", isPresented: Binding(
            get: { clipboard.detectedURL != nil },
            set: { if !$0 { clipboard.dismiss() } }
        )) {
            Button("打开") {
                if let link = clipboard.detectedURL {
                    switch link {
                    case .topic(let id): router.navigateToTopic(id: id)
                    case .node(let name): router.navigateToNode(name: name)
                    case .member(let username): router.navigateToMember(username: username)
                    }
                    clipboard.dismiss()
                }
            }
            Button("忽略", role: .cancel) {
                clipboard.dismiss()
            }
        } message: {
            if let link = clipboard.detectedURL {
                Text(link.description)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if settings.autoCheckClipboard {
                clipboard.checkClipboard()
            }
            cloudflare.checkIfNeeded()
        }
        .environment(\.openURL, OpenURLAction { url in
            if DeepLinkHandler.parse(url: url) != nil {
                DeepLinkHandler.handle(url: url, router: router)
                return .handled
            }

            guard settings.openLinksInApp,
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https"
            else {
                return .systemAction(url)
            }

            browserDestination = BrowserDestination(url: url)
            return .handled
        })
    }

    @ViewBuilder
    private var tabView: some View {
        @Bindable var r = router
        TabView(selection: $r.selectedTab) {
            Tab("主题", systemImage: "text.bubble", value: Router.Tab.home) {
                NavigationStack(path: router.path(for: .home)) {
                    HomeView()
                        .commonNavigationDestinations()
                }
                .toolbarVisibility(router.homePath.isEmpty ? .automatic : .hidden, for: .tabBar)
            }

            Tab("消息", systemImage: "bell", value: Router.Tab.notifications) {
                NavigationStack(path: router.path(for: .notifications)) {
                    NotificationListView()
                        .commonNavigationDestinations()
                }
                .toolbarVisibility(router.notificationsPath.isEmpty ? .automatic : .hidden, for: .tabBar)
            }
            .badge(auth.unreadCount)

            Tab("搜索", systemImage: "magnifyingglass", value: Router.Tab.search) {
                NavigationStack(path: router.path(for: .search)) {
                    SearchView()
                        .commonNavigationDestinations()
                }
                .toolbarVisibility(router.searchPath.isEmpty ? .automatic : .hidden, for: .tabBar)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            let showFAB = auth.isAuthed && router.selectedTab == .home && router.homePath.isEmpty
            Button {
                showNewTopic = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(theme.accentColor)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 80)
            .offset(y: showFAB && router.homeBarsVisible ? 0 : 200)
            .animation(.easeInOut(duration: 0.2), value: showFAB)
            .animation(.easeInOut(duration: 0.2), value: router.homeBarsVisible)
        }
    }
}

private struct BrowserDestination: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - Common Navigation Destinations

extension View {
    func commonNavigationDestinations() -> some View {
        self
            .navigationDestination(for: TopicBasic.self) { topic in
                TopicDetailView(topicId: topic.id, brief: topic)
            }
            .navigationDestination(for: MemberBasic.self) { member in
                MemberDetailView(username: member.username)
            }
            .navigationDestination(for: NodeBasic.self) { node in
                NodeDetailView(nodeName: node.name, brief: node)
            }
    }
}
