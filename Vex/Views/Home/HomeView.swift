import Kingfisher
import SwiftUI

struct HomeView: View {
    @Environment(FavoriteNodesManager.self) private var favoriteNodes
    @Environment(AuthManager.self) private var auth
    @Environment(Router.self) private var router
    @EnvironmentObject private var settings: AppSettingsManager

    @State private var tabs: [HomeTabOption] = []
    @AppStorage("home_selected_tab") private var selectedTab = "all"
    @State private var feeds: [HomeTopicFeed] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showProfile = false
    @State private var skipNextSelectedTabChange = false
    @State private var didLoadInitialFeeds = false

    private let client = V2EXClient.shared

    private var selectedTabLabel: String {
        tabs.first(where: { $0.value == selectedTab })?.label ?? "主题"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content
            if selectedTab == "xna" {
                XnaFeedView()
            } else {
                LottieRefreshableScrollView {
                    await loadFeeds()
                } content: {
                    if isLoading && feeds.isEmpty {
                        LottieLoadingView()
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(feeds) { feed in
                                NavigationLink(value: feed.topic) {
                                    TopicRow(feed: feed)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .overlay {
                    if let error, feeds.isEmpty {
                        ContentUnavailableView(
                            "加载失败",
                            systemImage: "exclamationmark.triangle",
                            description: Text(error)
                        )
                    }
                }
            }
        }
        .navigationTitle(selectedTabLabel)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 6) {
                    Button {
                        showProfile = true
                    } label: {
                        if settings.showAvatar,
                           let user = auth.user,
                           let urlStr = user.avatarLarge,
                           let url = URL(string: urlStr) {
                            KFImage(url)
                                .resizable()
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(favoriteNodes.nodes.prefix(5), id: \.name) { node in
                        Button(node.title) {
                            router.homePath.append(node)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.fill.tertiary)
                        .clipShape(Capsule())
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(tabs) { tab in
                        Button {
                            selectedTab = tab.value
                        } label: {
                            if selectedTab == tab.value {
                                Label(tab.label, systemImage: "checkmark")
                            } else {
                                Text(tab.label)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
                    .commonNavigationDestinations()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                showProfile = false
                            } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
            .toastOverlay()
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !didLoadInitialFeeds else { return }
            await loadTabs()
            didLoadInitialFeeds = true
            if feeds.isEmpty && selectedTab != "xna" {
                await loadFeeds()
            }
        }
        .onChange(of: selectedTab) {
            if skipNextSelectedTabChange {
                skipNextSelectedTabChange = false
                return
            }
            if selectedTab != "xna" {
                Task { await loadFeeds() }
            }
        }
    }

    private func loadTabs() async {
        do {
            tabs = try await client.getHomeTabs()
            // 持久化的 tab 不在可用列表中时，回退到第一个
            if !tabs.contains(where: { $0.value == selectedTab }),
               let first = tabs.first {
                skipNextSelectedTabChange = true
                selectedTab = first.value
            }
        } catch {
            tabs = [HomeTabOption(value: "all", label: "全部")]
        }
    }

    private func loadFeeds() async {
        isLoading = true
        error = nil
        do {
            feeds = try await client.getHomeFeeds(tab: selectedTab)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
