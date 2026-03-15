import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AuthManager {
    enum Status: Equatable {
        case none, loading, authed, visitor, failed, logout
    }

    var user: MemberDetail?
    var status: Status = .none
    var unreadCount: Int = 0
    var balance: BalanceBrief?
    private(set) var isDemoMode = false

    private var lastFetchedAt: Date?
    private let client = V2EXClient.shared

    var isAuthed: Bool { status == .authed }

    /// 审核员 demo 模式：模拟已登录状态，无需真实 V2EX 账号
    func enableDemoMode() {
        isDemoMode = true
        user = MemberDetail(
            id: 1,
            username: "AppReviewer",
            bio: "App Store Reviewer",
            btc: nil, github: nil, location: "Cupertino, CA",
            psn: nil, status: nil, tagline: "Reviewing apps with care",
            twitter: nil, url: nil, website: nil,
            created: Int(Date().timeIntervalSince1970) - 86400 * 365,
            lastModified: Int(Date().timeIntervalSince1970),
            avatarMini: "https://cdn.v2ex.com/gravatar/?s=24&d=retro",
            avatarNormal: "https://cdn.v2ex.com/gravatar/?s=48&d=retro",
            avatarLarge: "https://cdn.v2ex.com/gravatar/?s=73&d=retro"
        )
        status = .authed
        unreadCount = 3
        balance = BalanceBrief(gold: 128, silver: 45, bronze: 18)
        lastFetchedAt = Date()
    }

    func checkAuth(forceRefresh: Bool = false) async {
        guard status != .loading else { return }

        // Skip if checked recently (within 6 hours)
        if !forceRefresh, let last = lastFetchedAt, Date().timeIntervalSince(last) < 6 * 3600 {
            return
        }

        status = .loading
        do {
            if let member = try await client.getCurrentUser() {
                user = member
                status = .authed
                unreadCount = client.unreadCount
                balance = client.balanceBrief

                // 首页可能没有 balance_area，从 /balance 页面获取
                if balance == nil {
                    _ = try? await client.fetchHTML(path: "/balance")
                    balance = client.balanceBrief
                }
            } else {
                clearSessionState()
                status = .visitor
            }
            lastFetchedAt = Date()
        } catch {
            if case V2EXError.authRequired = error {
                clearSessionState()
                status = .visitor
            } else {
                status = .failed
            }
        }
    }

    func logout() async {
        isDemoMode = false
        await client.logout()
        clearSessionState()
        status = .logout
        lastFetchedAt = nil
    }

    /// Wrap a navigation action with auth check
    func requireAuth(action: @escaping () -> Void) -> () -> Void {
        return { [weak self] in
            guard self?.isAuthed == true else { return }
            action()
        }
    }

    func refreshUnreadCount() {
        unreadCount = client.unreadCount
        balance = client.balanceBrief
    }

    private func clearSessionState() {
        user = nil
        unreadCount = 0
        balance = nil
    }
}
