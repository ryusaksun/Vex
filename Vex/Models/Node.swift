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

    enum CodingKeys: String, CodingKey {
        case nodeId = "id"
        case name, title, header, topics, collected, theme
        case avatarLarge = "avatar_large"
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
