import Kingfisher
import SwiftUI

struct HomeView: View {
    @Environment(FavoriteNodesManager.self) private var favoriteNodes
    @Environment(AuthManager.self) private var auth
    @Environment(Router.self) private var router

    @State private var tabs: [HomeTabOption] = []
    @State private var selectedTab = "all"
    @State private var feeds: [HomeTopicFeed] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showProfile = false

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
                ScrollView {
                    if isLoading && feeds.isEmpty {
                        TopicListSkeleton()
                            .padding(.horizontal)
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
                .refreshable {
                    await loadFeeds()
                }
                .onScrollGeometryChange(for: Bool.self) { geo in
                    geo.contentOffset.y > 60
                } action: { _, isPastThreshold in
                    if !isPastThreshold {
                        router.homeBarsVisible = true
                    }
                }
                .onScrollPhaseChange { _, newPhase in
                    if newPhase == .idle {
                        router.homeBarsVisible = true
                    }
                }
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y
                } action: { oldValue, newValue in
                    let delta = newValue - oldValue
                    guard abs(delta) > 8 else { return }
                    let shouldShow = delta < 0
                    if shouldShow != router.homeBarsVisible {
                        router.homeBarsVisible = shouldShow
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
        .toolbar(router.homeBarsVisible ? .visible : .hidden, for: .navigationBar)
        .toolbar(router.homeBarsVisible && router.homePath.isEmpty ? .visible : .hidden, for: .tabBar)
        .animation(.easeInOut(duration: 0.2), value: router.homeBarsVisible)
        .navigationTitle(selectedTabLabel)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 6) {
                    Button {
                        showProfile = true
                    } label: {
                        if let user = auth.user, let urlStr = user.avatarLarge, let url = URL(string: urlStr) {
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
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTabs()
            // loadFeeds 会由 loadTabs 修改 selectedTab 后通过 onChange 触发
            // 如果 selectedTab 未变（仍为 "all"），则手动加载
            if feeds.isEmpty && selectedTab != "xna" {
                await loadFeeds()
            }
        }
        .onChange(of: selectedTab) {
            router.homeBarsVisible = true
            if selectedTab != "xna" {
                Task { await loadFeeds() }
            }
        }
    }

    private func loadTabs() async {
        do {
            tabs = try await client.getHomeTabs()
            if let first = tabs.first {
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
