import Foundation
import Observation

@Observable
@MainActor
final class FavoriteNodesManager {
    private static let key = "favorite_nodes"

    var nodes: [NodeBasic] = []

    init() {
        load()
    }

    func toggle(_ node: NodeBasic) {
        if contains(node) {
            remove(node)
        } else {
            add(node)
        }
    }

    func add(_ node: NodeBasic) {
        guard !contains(node) else { return }
        nodes.append(node)
        save()
    }

    func remove(_ node: NodeBasic) {
        nodes.removeAll { $0.name == node.name }
        save()
    }

    func contains(_ node: NodeBasic) -> Bool {
        nodes.contains { $0.name == node.name }
    }

    func move(from source: IndexSet, to destination: Int) {
        nodes.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(nodes) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([NodeBasic].self, from: data) else { return }
        nodes = decoded
    }
}
