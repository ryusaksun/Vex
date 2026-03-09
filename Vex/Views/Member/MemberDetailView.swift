import Kingfisher
import SwiftUI

struct MemberDetailView: View {
    let username: String

    @Environment(AuthManager.self) private var auth
    @Environment(AlertManager.self) private var alert
    @EnvironmentObject private var settings: AppSettingsManager

    @State private var detail: MemberDetail?
    @State private var meta: MemberMeta?
    @State private var selectedSegment = 0
    @State private var isLoading = false
    @State private var error: String?

    private let client = V2EXClient.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let detail {
                    // Header
                    memberHeader(detail)

                    // Segment picker
                    Picker("", selection: $selectedSegment) {
                        Text("主题").tag(0)
                        Text("回复").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    // Content
                    if selectedSegment == 0 {
                        MemberTopicsListView(username: username)
                    } else {
                        MemberRepliesListView(username: username)
                    }
                }
            }
        }
        .navigationTitle("@\(username)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let meta, auth.isAuthed {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button(meta.watched ? "取消关注" : "关注") {
                            Task { await toggleWatch() }
                        }
                        Button(meta.blocked ? "取消屏蔽" : "屏蔽", role: meta.blocked ? nil : .destructive) {
                            Task { await toggleBlock() }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .overlay {
            if isLoading && detail == nil {
                LottieLoadingView()
            } else if let error, detail == nil {
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            }
        }
        .task {
            await loadMember()
        }
    }

    @ViewBuilder
    private func memberHeader(_ detail: MemberDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                if settings.showAvatar {
                    KFImage(URL(string: HTMLParser.resolveURL(detail.avatarLarge)))
                        .resizable()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.username)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let tagline = detail.tagline, !tagline.isEmpty {
                        Text(tagline)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            // Info rows
            VStack(alignment: .leading, spacing: 6) {
                if let bio = detail.bio, !bio.isEmpty {
                    Label(bio, systemImage: "text.quote")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let location = detail.location, !location.isEmpty {
                    Label(location, systemImage: "location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let website = detail.website, !website.isEmpty {
                    Label(website, systemImage: "link")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                if let github = detail.github, !github.isEmpty {
                    Label(github, systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let twitter = detail.twitter, !twitter.isEmpty {
                    Label("@\(twitter)", systemImage: "at")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let meta {
                HStack(spacing: 12) {
                    if meta.watched {
                        Label("已关注", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if meta.blocked {
                        Label("已屏蔽", systemImage: "nosign")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            if let created = detail.created {
                let date = Date(timeIntervalSince1970: TimeInterval(created))
                Text("注册于 \(date, style: .date)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.fill.quaternary)
    }

    private func loadMember() async {
        isLoading = true
        do {
            let result = try await client.getMemberDetail(username: username)
            detail = result.detail
            meta = result.meta
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleWatch() async {
        guard let detail, var meta else { return }
        do {
            if meta.watched {
                try await client.unwatchMember(id: detail.id)
            } else {
                try await client.watchMember(id: detail.id)
            }
            meta.watched.toggle()
            self.meta = meta
            HapticManager.notification(.success)
            alert.show(.success, meta.watched ? "已关注" : "已取消关注")
        } catch {
            alert.show(.error, error.localizedDescription)
        }
    }

    private func toggleBlock() async {
        guard let detail, var meta else { return }
        do {
            if meta.blocked {
                try await client.unblockMember(id: detail.id)
            } else {
                try await client.blockMember(id: detail.id)
            }
            meta.blocked.toggle()
            self.meta = meta
            HapticManager.notification(.success)
            alert.show(.success, meta.blocked ? "已屏蔽" : "已取消屏蔽")
        } catch {
            alert.show(.error, error.localizedDescription)
        }
    }
}
