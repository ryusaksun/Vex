import Kingfisher
import SwiftUI

struct HomeView: View {
    @Environment(AuthManager.self) private var auth
    @EnvironmentObject private var settings: AppSettingsManager

    @State private var tabs: [HomeTabOption] = []
    @AppStorage("home_selected_tab") private var selectedTabKey = "all"
    @AppStorage("configured_home_tabs") private var configuredHomeTabsJSON = ""
    @State private var feeds: [HomeTopicFeed] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var error: String?
    @State private var showProfile = false
    @State private var skipNextSelectedTabChange = false
    @State private var didLoadInitialFeeds = false
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var hasMorePages = false
    @State private var loadFeedsTask: Task<Void, Never>?

    private let client = V2EXClient.shared

    private var selectedTabOption: HomeTabOption? {
        tabs.first { $0.storageKey == selectedTabKey || $0.value == selectedTabKey }
    }

    private var selectedTabLabel: String {
        selectedTabOption?.label ?? "主题"
    }

    var body: some View {
        let bottomTriggerThreshold = UIScreen.main.bounds.height + 160

        VStack(spacing: 0) {
            // Content
            if selectedTabOption?.type == .xna {
                XnaFeedView()
            } else {
                LottieRefreshableScrollView {
                    await loadFeeds(page: 1)
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

                            if hasMorePages {
                                Color.clear
                                    .frame(height: 1)
                                    .onGeometryChange(for: Bool.self) { proxy in
                                        proxy.frame(in: .global).minY < bottomTriggerThreshold
                                    } action: { isNearBottom in
                                        guard isNearBottom else { return }
                                        Task { await loadMoreFeeds() }
                                    }
                            }

                            if isLoadingMore {
                                ProgressView()
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity)
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
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(tabs) { tab in
                        Button {
                            selectedTabKey = tab.storageKey
                        } label: {
                            if tab.storageKey == selectedTabKey || tab.value == selectedTabKey {
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
            _ = await loadTabs()
            didLoadInitialFeeds = true
            if feeds.isEmpty && selectedTabOption?.type != .xna {
                await loadFeeds(page: 1)
            }
        }
        .onChange(of: configuredHomeTabsJSON) {
            Task {
                let selectedTabChanged = await loadTabs()
                if selectedTabChanged && selectedTabOption?.type != .xna {
                    await loadFeeds(page: 1)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudflareVerificationCompleted)) { _ in
            guard selectedTabOption?.type != .xna else { return }
            Task {
                _ = await loadTabs()
                await loadFeeds(page: 1)
            }
        }
        .onChange(of: selectedTabKey) {
            if skipNextSelectedTabChange {
                skipNextSelectedTabChange = false
                return
            }
            if selectedTabOption?.type != .xna {
                loadFeedsTask?.cancel()
                loadFeedsTask = Task { await loadFeeds(page: 1) }
            }
        }
    }

    @discardableResult
    private func loadTabs() async -> Bool {
        let previousSelectedTab = selectedTabKey

        do {
            let remoteTabs = try await client.getHomeTabs()
            tabs = settings.configuredHomeTabs(from: remoteTabs)
            if let resolved = selectedTabOption {
                if selectedTabKey != resolved.storageKey {
                    skipNextSelectedTabChange = true
                    selectedTabKey = resolved.storageKey
                }
            } else if let first = tabs.first {
                skipNextSelectedTabChange = true
                selectedTabKey = first.storageKey
            }
        } catch {
            tabs = settings.configuredHomeTabs(from: settings.fallbackHomeTabs)
            if let resolved = selectedTabOption {
                if selectedTabKey != resolved.storageKey {
                    skipNextSelectedTabChange = true
                    selectedTabKey = resolved.storageKey
                }
            } else if let first = tabs.first {
                skipNextSelectedTabChange = true
                selectedTabKey = first.storageKey
            }
        }

        return previousSelectedTab != selectedTabKey
    }

    private func loadFeeds(page: Int) async {
        let requestedTabKey = selectedTabKey
        let requestedTabOption = tabs.first { $0.storageKey == requestedTabKey || $0.value == requestedTabKey }
        let requestedTabValue = requestedTabOption?.value ?? requestedTabKey

        if page == 1 {
            isLoading = true
            isLoadingMore = false
            error = nil
            currentPage = 1
            totalPages = 1
            hasMorePages = false
        } else {
            guard !isLoading && !isLoadingMore && hasMorePages else { return }
            isLoadingMore = true
        }

        do {
            let response: PaginatedResponse<HomeTopicFeed>

            if requestedTabOption?.type == .node {
                let nodeResponse = try await client.getNodeFeeds(name: requestedTabValue, page: page)
                let node = NodeBasic(
                    name: requestedTabValue,
                    title: requestedTabOption?.label ?? requestedTabValue
                )
                let mappedFeeds = nodeResponse.data.map {
                    HomeTopicFeed(
                        topic: $0.topic,
                        member: $0.member,
                        lastReplyTime: nil,
                        lastReplyBy: nil,
                        node: node
                    )
                }
                response = PaginatedResponse(data: mappedFeeds, pagination: nodeResponse.pagination)
            } else {
                response = try await client.getHomeFeeds(tab: requestedTabValue, page: page)
            }

            print("[HomeView] tab=\(requestedTabValue) page=\(page) feedsCount=\(response.data.count) pagination=\(response.pagination.current)/\(response.pagination.total)")

            guard requestedTabKey == selectedTabKey else { return }

            let newFeeds: [HomeTopicFeed]
            if page == 1 {
                newFeeds = response.data
                feeds = response.data
            } else {
                let existingIDs = Set(feeds.map(\.id))
                newFeeds = response.data.filter { !existingIDs.contains($0.id) }
                feeds.append(contentsOf: newFeeds)
            }

            currentPage = response.pagination.current
            totalPages = response.pagination.total
            hasMorePages = response.pagination.total > response.pagination.current
            print("[HomeView] after update: currentPage=\(currentPage) totalPages=\(totalPages) hasMorePages=\(hasMorePages) totalFeeds=\(feeds.count)")
        } catch {
            print("[HomeView] ERROR loading tab=\(requestedTabValue) page=\(page): \(error)")
            guard requestedTabKey == selectedTabKey else { return }
            self.error = error.localizedDescription
            if page > 1 {
                hasMorePages = false
            }
        }

        if requestedTabKey == selectedTabKey {
            isLoading = false
            isLoadingMore = false
        }
    }

    private func loadMoreFeeds() async {
        await loadFeeds(page: currentPage + 1)
    }
}
