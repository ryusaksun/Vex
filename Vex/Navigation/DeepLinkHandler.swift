import Foundation

enum DeepLinkHandler {
    enum DeepLink {
        case topic(Int)
        case node(String)
        case member(String)
    }

    static func parse(url: URL) -> DeepLink? {
        // vex://t/{id}  or  vex:///t/{id}
        if url.scheme == "vex" {
            let host = url.host
            let components = url.pathComponents

            // 从 host 或 pathComponents 中提取路由类型和参数
            let routeType: String?
            let routeParam: String?

            if let host, !host.isEmpty {
                // vex://t/123 — host="t", pathComponents=["/", "123"]
                routeType = host
                routeParam = components.count > 1 ? components[1] : nil
            } else if components.count > 2 {
                // vex:///t/123 — pathComponents=["/", "t", "123"]
                routeType = components[1]
                routeParam = components[2]
            } else {
                routeType = nil
                routeParam = nil
            }

            if let routeType {
                switch routeType {
                case "t":
                    if let param = routeParam, let id = Int(param) {
                        return .topic(id)
                    }
                case "go":
                    if let param = routeParam, !param.isEmpty, param != "/" {
                        return .node(param)
                    }
                case "member":
                    if let param = routeParam, !param.isEmpty, param != "/" {
                        return .member(param)
                    }
                default:
                    break
                }
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
