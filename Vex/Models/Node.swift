import Foundation

struct NodeBasic: Codable, Hashable, Identifiable, Sendable {
    var id: String { name }
    let name: String
    let title: String
}

struct NodeExtra: Codable, Hashable, Identifiable, Sendable {
    var id: String { name }
    let name: String
    let title: String
    let avatarLarge: String
    let topics: Int
}

struct NodeDetail: Codable, Hashable, Sendable {
    var nodeId: Int?
    let name: String
    let title: String
    var header: String
    var avatarLarge: String
    var topics: Int
    var collected: Bool
    var theme: NodeTheme?

    var basic: NodeBasic {
        NodeBasic(name: name, title: title)
    }

    // 注意：如果通过 fetchJSON 解码，需确保 decoder 不使用 convertFromSnakeCase
    enum CodingKeys: String, CodingKey {
        case nodeId = "id"
        case name, title, header, topics, collected, theme
        case avatarLarge
    }
}

struct NodeTheme: Codable, Hashable, Sendable {
    let bgColor: String?
    let color: String?
}

struct NodeGroup: Codable, Hashable, Identifiable, Sendable {
    var id: String { name }
    let title: String
    let name: String
    let nodes: [NodeBasic]
}
