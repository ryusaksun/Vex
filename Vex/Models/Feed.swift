import Foundation

struct HomeTabOption: Codable, Hashable, Identifiable, Sendable {
    var id: String { storageKey }
    let value: String
    let label: String
    var type: TabType
    var disabled: Bool

    var storageKey: String { "\(type.rawValue):\(value)" }

    enum TabType: String, Codable, Sendable {
        case home, node, user, xna
    }

    init(value: String, label: String, type: TabType = .home, disabled: Bool = false) {
        self.value = value
        self.label = label
        self.type = type
        self.disabled = disabled
    }
}

struct HomeTopicFeed: Codable, Hashable, Identifiable, Sendable {
    var id: Int { topic.id }
    let topic: TopicBasic
    let member: MemberBasic
    let lastReplyTime: String?
    let lastReplyBy: String?
    let node: NodeBasic
}

struct NodeTopicFeed: Codable, Hashable, Identifiable, Sendable {
    var id: Int { topic.id }
    let topic: TopicBasic
    let member: MemberBasic
    let characters: Int
    let clicks: Int
}

struct MemberTopicFeed: Codable, Hashable, Identifiable, Sendable {
    var id: Int { topic.id }
    let topic: TopicBasic
    let node: NodeBasic
    let lastReplyTime: String?
    let lastReplyBy: String?
}

struct RepliedTopicFeed: Codable, Hashable, Identifiable, Sendable {
    var id: String { "\(topic.id)-\(member.username)-\(replyTime)-\(replyContentRendered.prefix(64))" }
    let topic: TopicBasic
    let member: MemberBasic
    let replyContentRendered: String
    let replyTime: String
}

struct CollectedTopicFeed: Codable, Hashable, Identifiable, Sendable {
    var id: Int { topic.id }
    let topic: TopicBasic
    let votes: Int?
    let member: MemberBasic
    let node: NodeBasic
    let lastReplyTime: String?
    let lastReplyBy: String?
}

struct XnaFeed: Codable, Hashable, Identifiable, Sendable {
    var id: String { url }
    let title: String
    let member: MemberBasic
    let source: XnaSource
    let url: String
    let updatedAt: String

    struct XnaSource: Codable, Hashable, Sendable {
        let name: String
        let link: String
    }
}

struct V2EXNotification: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let member: MemberBasic
    let topic: TopicBasic
    let action: NotificationAction
    let contentRendered: String
    let time: String

    enum NotificationAction: String, Codable, Sendable {
        case reply, collect, thank, thankReply = "thank_reply"
    }
}

struct BalanceBrief: Codable, Hashable, Sendable {
    var gold: Int
    var silver: Int
    var bronze: Int
}

struct BalanceRecord: Codable, Hashable, Identifiable, Sendable {
    var id: String { "\(type)-\(time)-\(amount)-\(balance)-\(description)" }
    let type: String
    let time: String
    let amount: String
    let balance: String
    let description: String
}

struct SearchHit: Codable, Hashable, Identifiable, Sendable {
    var id: String { _id }
    let _id: String
    let _score: Double
    let highlight: SearchHighlight?
    let _source: SearchSource

    struct SearchHighlight: Codable, Hashable, Sendable {
        let content: [String]?
        let title: [String]?
    }

    struct SearchSource: Codable, Hashable, Sendable {
        let node: Int
        let replies: Int
        let created: String
        let member: String
        let id: Int
        let title: String
        let content: String
    }
}
