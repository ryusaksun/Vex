import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class Router {
    enum Tab: String, CaseIterable {
        case home, notifications, search
    }

    var selectedTab: Tab = .home
    var homeBarsVisible = true
    var homePath = NavigationPath()
    var notificationsPath = NavigationPath()
    var searchPath = NavigationPath()

    func navigateToTopic(id: Int) {
        selectedTab = .home
        homePath.append(TopicBasic(id: id, title: "", replies: 0))
    }

    func navigateToNode(name: String) {
        selectedTab = .home
        homePath.append(NodeBasic(name: name, title: name))
    }

    func navigateToMember(username: String) {
        let member = MemberBasic(username: username, avatarMini: "", avatarNormal: "", avatarLarge: "")
        switch selectedTab {
        case .home:
            homePath.append(member)
        case .notifications:
            notificationsPath.append(member)
        case .search:
            searchPath.append(member)
        }
    }

    func path(for tab: Tab) -> Binding<NavigationPath> {
        switch tab {
        case .home: return Binding(get: { self.homePath }, set: { self.homePath = $0 })
        case .notifications: return Binding(get: { self.notificationsPath }, set: { self.notificationsPath = $0 })
        case .search: return Binding(get: { self.searchPath }, set: { self.searchPath = $0 })
        }
    }

    func popToRoot(tab: Tab) {
        switch tab {
        case .home: homePath = NavigationPath()
        case .notifications: notificationsPath = NavigationPath()
        case .search: searchPath = NavigationPath()
        }
    }
}
