import SwiftUI

struct FavoriteNodesSettingsView: View {
    @Environment(FavoriteNodesManager.self) private var favoriteNodes

    @State private var groups: [NodeGroup] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var error: String?

    private let client = V2EXClient.shared

    var filteredGroups: [NodeGroup] {
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
            if !favoriteNodes.nodes.isEmpty {
                Section("已收藏") {
                    ForEach(favoriteNodes.nodes) { node in
                        Text(node.title)
                    }
                    .onDelete { offsets in
                        for index in offsets.sorted().reversed() {
                            favoriteNodes.remove(favoriteNodes.nodes[index])
                        }
                    }
                    .onMove { favoriteNodes.move(from: $0, to: $1) }
                }
            }

            ForEach(filteredGroups) { group in
                Section(group.title) {
                    FlowLayout(spacing: 8) {
                        ForEach(group.nodes) { node in
                            let isFav = favoriteNodes.contains(node)
                            Button {
                                favoriteNodes.toggle(node)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(node.title)
                                    if isFav {
                                        Image(systemName: "checkmark")
                                            .font(.caption2)
                                    }
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isFav ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemFill))
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
        .navigationTitle("节点收藏")
        .toolbar { EditButton() }
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
}
