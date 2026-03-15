import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettingsManager

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
                    HomeTabSettingsView()
                } label: {
                    Label("首页标签", systemImage: "line.3.horizontal.decrease.circle")
                }
            }

            Section("显示") {
                Toggle("显示头像", isOn: $settings.showAvatar)
                Toggle("显示最后回复者", isOn: $settings.showLastReply)
            }

            Section("行为") {
                Toggle("应用内打开链接", isOn: $settings.openLinksInApp)
                Toggle("触觉反馈", isOn: $settings.hapticFeedback)
                Toggle("自动检测剪贴板", isOn: $settings.autoCheckClipboard)
            }

            Section {
                SecureField("Imgur Client-ID", text: $settings.imgurClientId)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("图床")
            } footer: {
                Text("使用 Imgur 匿名上传图片。前往 api.imgur.com 注册应用获取 Client-ID，上传的图片链接可在 V2EX 网页端自动显示为图片。")
            }

            if settings.isImageUploadConfigured {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("图床已配置，回复时可上传图片")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("缓存") {
                Button("清除缓存") {
                    Task {
                        await CacheManager.shared.clearAll()
                    }
                }
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ViewedTopicsView: View {
    @Environment(ViewedTopicsManager.self) private var viewedTopics

    var body: some View {
        List {
            ForEach(viewedTopics.topics) { topic in
                NavigationLink {
                    TopicDetailView(topicId: topic.id, brief: TopicBasic(id: topic.id, title: topic.title, replies: 0))
                } label: {
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
