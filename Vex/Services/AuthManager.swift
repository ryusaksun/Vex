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

    private var lastFetchedAt: Date?
    private let client = V2EXClient.shared

    var isAuthed: Bool { status == .authed }

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
                status = .visitor
            }
            lastFetchedAt = Date()
        } catch {
            if case V2EXError.authRequired = error {
                status = .visitor
            } else {
                status = .failed
            }
        }
    }

    func logout() async {
        await client.logout()
        user = nil
        status = .logout
        unreadCount = 0
        balance = nil
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
}
