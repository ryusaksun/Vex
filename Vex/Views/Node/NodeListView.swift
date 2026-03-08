import SwiftUI

struct NodeListView: View {
    @State private var groups: [NodeGroup] = []
    @State private var isLoading = false
    @State private var searchText = ""

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
            ForEach(filteredGroups) { group in
                Section(group.title) {
                    FlowLayout(spacing: 8) {
                        ForEach(group.nodes) { node in
                            NavigationLink(value: node) {
                                Text(node.title)
                                    .font(.subheadline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.fill.tertiary)
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
        .navigationTitle("节点")
        .navigationDestination(for: NodeBasic.self) { node in
            NodeDetailView(nodeName: node.name, brief: node)
        }
        .refreshable {
            await loadGroups()
        }
        .overlay {
            if isLoading && groups.isEmpty {
                ProgressView()
            }
        }
        .task {
            await loadGroups()
        }
    }

    private func loadGroups() async {
        isLoading = true
        do {
            groups = try await client.getNodeGroups()
        } catch {}
        isLoading = false
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
