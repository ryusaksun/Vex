import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("外观") {
                NavigationLink {
                    ThemeSettingsView()
                } label: {
                    Label("主题设置", systemImage: "paintbrush")
                }
            }

            Section("浏览") {
                NavigationLink {
                    FavoriteNodesSettingsView()
                } label: {
                    Label("节点收藏", systemImage: "star")
                }
                NavigationLink {
                    NodeListView()
                } label: {
                    Label("全部节点", systemImage: "sparkles")
                }
            }

            Section("偏好") {
                NavigationLink {
                    PreferenceSettingsView()
                } label: {
                    Label("偏好设置", systemImage: "slider.horizontal.3")
                }
            }

            Section("缓存") {
                Button("清除缓存") {
                    Task {
                        await CacheManager.shared.clearAll()
                    }
                }
            }

            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("设置")
    }
}

struct ViewedTopicsView: View {
    @Environment(ViewedTopicsManager.self) private var viewedTopics

    var body: some View {
        List {
            ForEach(viewedTopics.topics) { topic in
                NavigationLink(value: TopicBasic(id: topic.id, title: topic.title, replies: 0)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(topic.title)
                            .font(.body)
                            .lineLimit(2)

                        HStack {
                            Text(topic.member.username)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(topic.node.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(topic.viewedAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("浏览历史")
        .navigationDestination(for: TopicBasic.self) { topic in
            TopicDetailView(topicId: topic.id, brief: topic)
        }
        .toolbar {
            if !viewedTopics.topics.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清除", role: .destructive) {
                        viewedTopics.clearAll()
                    }
                }
            }
        }
        .overlay {
            if viewedTopics.topics.isEmpty {
                ContentUnavailableView(
                    "暂无浏览记录",
                    systemImage: "clock",
                    description: Text("浏览过的主题会显示在这里")
                )
            }
        }
    }
}
