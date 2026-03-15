import SwiftUI

struct HomeTabSettingsView: View {
    @EnvironmentObject private var settings: AppSettingsManager

    @State private var availableTabs: [HomeTabOption] = []
    @State private var activeTabs: [HomeTabOption] = []
    @State private var isLoading = false
    @State private var error: String?

    private let client = V2EXClient.shared

    private var inactiveTabs: [HomeTabOption] {
        let activeKeys = Set(activeTabs.map(\.storageKey))
        return availableTabs.filter { !activeKeys.contains($0.storageKey) }
    }

    var body: some View {
        List {
            // 已启用
            Section {
                if activeTabs.isEmpty && !isLoading {
                    ContentUnavailableView(
                        "暂无首页标签",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("至少保留一个首页标签")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(activeTabs) { tab in
                        HStack(spacing: 10) {
                            Image(systemName: tabIcon(tab))
                                .foregroundStyle(.tint)
                                .frame(width: 20)
                            Text(tab.label)
                            Spacer()
                            if tab.type == .node {
                                Text("节点")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.fill.tertiary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    .onDelete(perform: deleteTabs)
                    .onMove { activeTabs.move(fromOffsets: $0, toOffset: $1); persistTabs() }
                }
            } header: {
                HStack {
                    Text("已启用（\(activeTabs.count)）")
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            } footer: {
                Text("拖拽排序，左滑移除。首页将按此顺序显示标签。")
            }

            // 可添加
            if !inactiveTabs.isEmpty {
                Section {
                    ForEach(inactiveTabs) { tab in
                        Button {
                            withAnimation {
                                activeTabs.append(tab)
                                persistTabs()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                                    .frame(width: 20)
                                Text(tab.label)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if tab.type == .node {
                                    Text("节点")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.fill.tertiary)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                    }
                } header: {
                    Text("可添加")
                }
            }

            // 添加节点 + 恢复默认
            Section {
                NavigationLink {
                    HomeTabNodePickerView(activeTabs: $activeTabs) {
                        persistTabs()
                    }
                } label: {
                    Label("添加节点标签", systemImage: "plus.rectangle.on.rectangle")
                }

                Button(role: .destructive) {
                    withAnimation {
                        settings.resetConfiguredHomeTabs()
                        activeTabs = settings.configuredHomeTabs(from: availableTabs)
                    }
                } label: {
                    Label("恢复默认排序", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("首页标签")
        .toolbar {
            if !activeTabs.isEmpty {
                EditButton()
            }
        }
        .task {
            // 先用回退数据立即展示，避免空白等待
            let fallback = settings.fallbackHomeTabs
            availableTabs = fallback
            activeTabs = settings.configuredHomeTabs(from: fallback)
            // 再后台加载远程数据更新
            await loadRemoteTabs()
        }
    }

    private func loadRemoteTabs() async {
        isLoading = true
        error = nil
        do {
            let remoteTabs = try await client.getHomeTabs()
            let mergedTabs = settings.mergedHomeTabs(remoteTabs)
            availableTabs = mergedTabs
            activeTabs = settings.configuredHomeTabs(from: mergedTabs)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func persistTabs() {
        settings.saveConfiguredHomeTabs(activeTabs)
    }

    private func deleteTabs(at offsets: IndexSet) {
        guard activeTabs.count > offsets.count else { return }
        activeTabs.remove(atOffsets: offsets)
        persistTabs()
    }

    private func tabIcon(_ tab: HomeTabOption) -> String {
        switch tab.value {
        case "hot": return "flame"
        case "all": return "square.grid.2x2"
        case "recent": return "clock"
        case "tech": return "cpu"
        case "creative": return "paintbrush"
        case "play": return "gamecontroller"
        case "apple": return "apple.logo"
        case "jobs": return "briefcase"
        case "deals": return "tag"
        case "city": return "building.2"
        case "qna": return "questionmark.bubble"
        case "r2": return "r.square"
        case "xna": return "antenna.radiowaves.left.and.right"
        default:
            return tab.type == .node ? "number" : "text.bubble"
        }
    }
}

struct HomeTabNodePickerView: View {
    @Binding var activeTabs: [HomeTabOption]
    let onChange: () -> Void

    @State private var groups: [NodeGroup] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var error: String?

    private let client = V2EXClient.shared

    private var filteredGroups: [NodeGroup] {
        if searchText.isEmpty { return groups }
        return groups.compactMap { group in
            let filtered = group.nodes.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
            guard !filtered.isEmpty else { return nil }
            return NodeGroup(title: group.title, name: group.name, nodes: filtered)
        }
    }

    var body: some View {
        List {
            ForEach(filteredGroups) { group in
                Section(group.title) {
                    FlowLayout(spacing: 8) {
                        ForEach(group.nodes) { node in
                            let nodeTab = HomeTabOption(value: node.name, label: node.title, type: .node)
                            let isSelected = activeTabs.contains { $0.storageKey == nodeTab.storageKey }
                            Button {
                                toggle(node)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(node.title)
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.caption2)
                                    }
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "搜索节点")
        .navigationTitle("添加节点")
        .overlay {
            if isLoading && groups.isEmpty {
                LottieLoadingView()
            } else if let error, groups.isEmpty {
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            }
        }
        .task {
            await loadGroups()
        }
    }

    private func loadGroups() async {
        isLoading = true
        error = nil
        do {
            groups = try await client.getNodeGroups()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func toggle(_ node: NodeBasic) {
        let nodeTab = HomeTabOption(value: node.name, label: node.title, type: .node)

        if let index = activeTabs.firstIndex(where: { $0.storageKey == nodeTab.storageKey }) {
            activeTabs.remove(at: index)
        } else {
            activeTabs.append(nodeTab)
        }
        onChange()
    }
}
