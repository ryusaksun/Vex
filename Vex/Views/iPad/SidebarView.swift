import SwiftUI

struct SidebarView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(Router.self) private var router

    @State private var showProfile = false

    var body: some View {
        @Bindable var r = router
        NavigationSplitView {
            List {
                Section("浏览") {
                    sidebarButton(tab: .home, label: "主题", icon: "text.bubble")
                }

                Section("账户") {
                    sidebarButton(tab: .notifications, label: "消息", icon: "bell", badge: auth.unreadCount)
                    Button {
                        showProfile = true
                    } label: {
                        Label("我的", systemImage: "face.smiling")
                    }
                }

                Section {
                    sidebarButton(tab: .search, label: "搜索", icon: "magnifyingglass")
                }
            }
            .navigationTitle("Vex")
        } detail: {
            switch router.selectedTab {
            case .home:
                NavigationStack(path: router.path(for: .home)) {
                    HomeView()
                        .commonNavigationDestinations()
                }
            case .notifications:
                NavigationStack(path: router.path(for: .notifications)) {
                    NotificationListView()
                        .commonNavigationDestinations()
                }
            case .search:
                NavigationStack(path: router.path(for: .search)) {
                    SearchView()
                        .commonNavigationDestinations()
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
                    .commonNavigationDestinations()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") {
                                showProfile = false
                            }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func sidebarButton(tab: Router.Tab, label: String, icon: String, badge: Int = 0) -> some View {
        Button {
            router.selectedTab = tab
        } label: {
            HStack {
                Label(label, systemImage: icon)
                    .foregroundStyle(router.selectedTab == tab ? Color.accentColor : .primary)
                if badge > 0 {
                    Spacer()
                    Text("\(badge)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .listRowBackground(router.selectedTab == tab ? Color.accentColor.opacity(0.1) : nil)
    }
}
