import SwiftUI

struct NodeSelectSheet: View {
    @Binding var selectedNode: NodeBasic?

    @Environment(\.dismiss) private var dismiss

    @State private var groups: [NodeGroup] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var error: String?

    private let client = V2EXClient.shared

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    ForEach(groups) { group in
                        Section(group.title) {
                            ForEach(group.nodes) { node in
                                nodeRow(node)
                            }
                        }
                    }
                } else {
                    ForEach(filteredNodes) { node in
                        nodeRow(node)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "搜索节点")
            .navigationTitle("选择节点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
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
                await loadNodes()
            }
        }
    }

    @ViewBuilder
    private func nodeRow(_ node: NodeBasic) -> some View {
        Button {
            selectedNode = node
            dismiss()
        } label: {
            HStack {
                Text(node.title)
                Spacer()
                if selectedNode?.name == node.name {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private var filteredNodes: [NodeBasic] {
        let query = searchText.lowercased()
        return groups.flatMap(\.nodes).filter {
            $0.title.lowercased().contains(query) || $0.name.lowercased().contains(query)
        }
    }

    private func loadNodes() async {
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
