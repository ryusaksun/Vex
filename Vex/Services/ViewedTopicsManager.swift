import Foundation
import Observation

@Observable
@MainActor
final class ViewedTopicsManager {
    private let storageKey = "vex_viewed_topics"
    private(set) var topics: [ViewedTopic] = []

    init() {
        load()
    }

    func markViewed(topic: TopicDetail) {
        let viewed = ViewedTopic(
            id: topic.id,
            title: topic.title,
            member: topic.member,
            node: topic.node,
            viewedAt: Date()
        )

        // Remove existing entry for same topic
        topics.removeAll { $0.id == topic.id }
        // Insert at beginning
        topics.insert(viewed, at: 0)
        // Keep max 200
        if topics.count > 200 {
            topics = Array(topics.prefix(200))
        }
        save()
    }

    func isViewed(topicId: Int) -> Bool {
        topics.contains { $0.id == topicId }
    }

    func clearAll() {
        topics.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ViewedTopic].self, from: data) else { return }
        topics = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(topics) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
