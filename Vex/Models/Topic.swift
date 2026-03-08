import Foundation

struct TopicBasic: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let title: String
    var replies: Int
}

struct TopicDetail: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let title: String
    var replies: Int
    let member: MemberBasic
    let contentRendered: String
    let createdTime: String
    let node: NodeBasic
    var subtles: [TopicSubtle]
    var collected: Bool
    var thanked: Bool
    var blocked: Bool
    var reported: Bool
    var clicks: Int
    var canAppend: Bool
    var canEdit: Bool
    var canMove: Bool

    var basic: TopicBasic {
        TopicBasic(id: id, title: title, replies: replies)
    }
}

struct TopicSubtle: Codable, Hashable, Sendable {
    let meta: String
    let contentRendered: String
}

struct TopicReply: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let num: Int
    let content: String
    let contentRendered: String
    let replyTime: String
    let replyDevice: String?
    let thanksCount: Int
    let member: MemberBasic
    let memberIsOp: Bool
    let memberIsMod: Bool
    let membersMentioned: [String]
    let repliedTo: [Int]?
    var thanked: Bool
}

struct ViewedTopic: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let title: String
    let member: MemberBasic
    let node: NodeBasic
    let viewedAt: Date
}
