import Kingfisher
import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AlertManager.self) private var alert
    @EnvironmentObject private var settings: AppSettingsManager

    @State private var isSigningIn = false
    @State private var hasSigned = false

    private let client = V2EXClient.shared

    var body: some View {
        List {
            if let user = auth.user {
                // User info section
                Section {
                    HStack(spacing: 14) {
                        if settings.showAvatar {
                            KFImage(URL(string: HTMLParser.resolveURL(user.avatarLarge)))
                                .resizable()
                                .placeholder {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundStyle(.quaternary)
                                }
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(user.username)
                                    .font(.headline)

                                if let balance = auth.balance {
                                    Spacer().frame(minWidth: 12)
                                    NavigationLink {
                                        BalanceView()
                                    } label: {
                                        HStack(spacing: 8) {
                                            HStack(spacing: 2) {
                                                Image(systemName: "circle.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(.yellow)
                                                Text("\(balance.gold)")
                                                    .font(.caption)
                                            }
                                            HStack(spacing: 2) {
                                                Image(systemName: "circle.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(.gray)
                                                Text("\(balance.silver)")
                                                    .font(.caption)
                                            }
                                            HStack(spacing: 2) {
                                                Image(systemName: "circle.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(.brown)
                                                Text("\(balance.bronze)")
                                                    .font(.caption)
                                            }
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            if let tagline = user.tagline, !tagline.isEmpty {
                                Text(tagline)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Daily signin
                Section {
                    Button {
                        Task { await dailySignin() }
                    } label: {
                        Label(hasSigned ? "今日已签到" : "每日签到", systemImage: hasSigned ? "gift.fill" : "gift")
                    }
                    .disabled(hasSigned || isSigningIn)
                }

                // My content
                Section("我的内容") {
                    NavigationLink {
                        CollectedTopicsView()
                    } label: {
                        Label("收藏的主题", systemImage: "star")
                    }

                    NavigationLink {
                        CreatedTopicsView(username: user.username)
                    } label: {
                        Label("创建的主题", systemImage: "square.and.pencil")
                    }

                    NavigationLink {
                        RepliedTopicsView(username: user.username)
                    } label: {
                        Label("回复的主题", systemImage: "arrowshape.turn.up.left")
                    }

                    NavigationLink {
                        ViewedTopicsView()
                    } label: {
                        Label("浏览历史", systemImage: "clock")
                    }
                }

                // Settings
                Section("设置") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("偏好设置", systemImage: "gearshape")
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("关于", systemImage: "info.circle")
                    }
                }

                // Sign out
                Section {
                    Button(role: .destructive) {
                        Task { await auth.logout() }
                    } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } else {
                // Not logged in
                Section {
                    NavigationLink {
                        SignInView()
                    } label: {
                        Label("登录以使用全部功能", systemImage: "person.circle")
                    }

                    Button {
                        auth.enableDemoMode()
                    } label: {
                        Label("Demo 模式（审核员入口）", systemImage: "person.badge.shield.checkmark")
                    }
                    .foregroundStyle(.secondary)
                }

                // Settings (available without login)
                Section("设置") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("偏好设置", systemImage: "gearshape")
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("关于", systemImage: "info.circle")
                    }
                }
            }
        }
        .navigationTitle("我的")
        .task {
            if auth.isAuthed {
                if let signed = try? await client.checkDailySigninStatus() {
                    hasSigned = signed
                }
            }
        }
    }

    private func dailySignin() async {
        if auth.isDemoMode {
            HapticManager.notification(.success)
            alert.show(.info, "Demo 模式：签到演示")
            hasSigned = true
            return
        }
        isSigningIn = true
        do {
            try await client.dailySignin()
            HapticManager.notification(.success)
            alert.show(.success, "签到成功")
            hasSigned = true
            auth.refreshUnreadCount()
        } catch {
            if case V2EXError.dailySigned = error {
                alert.show(.info, "今日已签到")
                hasSigned = true
            } else {
                alert.show(.error, error.localizedDescription)
            }
        }
        isSigningIn = false
    }
}
