import Foundation

enum DeepLinkHandler {
    enum DeepLink {
        case topic(Int)
        case node(String)
        case member(String)
    }

    static func parse(url: URL) -> DeepLink? {
        // vex://t/{id}
        if url.scheme == "vex" {
            let path = url.host ?? url.path
            let components = url.pathComponents

            if path == "t" || (components.count > 1 && components[1] == "t") {
                let idStr = components.count > 2 ? components[2] : url.lastPathComponent
                if let id = Int(idStr) {
                    return .topic(id)
                }
            }
            if path == "go" || (components.count > 1 && components[1] == "go") {
                let name = components.count > 2 ? components[2] : url.lastPathComponent
                return .node(name)
            }
            if path == "member" || (components.count > 1 && components[1] == "member") {
                let username = components.count > 2 ? components[2] : url.lastPathComponent
                return .member(username)
            }
        }

        // https://www.v2ex.com/t/{id}
        if url.host?.contains("v2ex.com") == true {
            let components = url.pathComponents
            if components.count >= 3 && components[1] == "t",
               let id = Int(components[2]) {
                return .topic(id)
            }
            if components.count >= 3 && components[1] == "go" {
                return .node(components[2])
            }
            if components.count >= 3 && components[1] == "member" {
                return .member(components[2])
            }
        }

        return nil
    }

    @MainActor
    static func handle(url: URL, router: Router) {
        guard let deepLink = parse(url: url) else { return }
        switch deepLink {
        case .topic(let id):
            router.navigateToTopic(id: id)
        case .node(let name):
            router.navigateToNode(name: name)
        case .member(let username):
            router.navigateToMember(username: username)
        }
    }
}
