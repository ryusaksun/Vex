import Foundation

struct MemberBasic: Codable, Hashable, Identifiable, Sendable {
    var id: String { username }
    let username: String
    let avatarMini: String
    let avatarNormal: String
    let avatarLarge: String

    static func avatarURLs(from src: String, alt: String) -> MemberBasic {
        MemberBasic(
            username: alt,
            avatarMini: Self.mapAvatarSize(src, size: .mini),
            avatarNormal: Self.mapAvatarSize(src, size: .normal),
            avatarLarge: Self.mapAvatarSize(src, size: .large)
        )
    }

    enum AvatarSize: String {
        case mini, normal, large

        var gravatar: String {
            switch self {
            case .mini: return "s=24"
            case .normal: return "s=48"
            case .large: return "s=73"
            }
        }

        var v2ex: String {
            switch self {
            case .mini: return "_mini."
            case .normal: return "_normal."
            case .large: return "_large."
            }
        }
    }

    static func mapAvatarSize(_ url: String, size: AvatarSize) -> String {
        var result = url
        if result.contains("gravatar.com") {
            result = result.replacingOccurrences(
                of: #"s=\d+"#, with: size.gravatar,
                options: .regularExpression
            )
        } else {
            for s in [AvatarSize.mini, .normal, .large] {
                result = result.replacingOccurrences(of: s.v2ex, with: size.v2ex)
            }
        }
        return result
    }
}

struct MemberDetail: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let username: String
    let bio: String?
    let btc: String?
    let github: String?
    let location: String?
    let psn: String?
    let status: String?
    let tagline: String?
    let twitter: String?
    let url: String?
    let website: String?
    let created: Int?
    let lastModified: Int?
    let avatarMini: String?
    let avatarNormal: String?
    let avatarLarge: String?

    var basic: MemberBasic {
        MemberBasic(
            username: username,
            avatarMini: avatarMini ?? "",
            avatarNormal: avatarNormal ?? "",
            avatarLarge: avatarLarge ?? ""
        )
    }

    // CodingKeys 不需要手动定义 — fetchJSON 的 .convertFromSnakeCase 自动处理
}

struct MemberMeta: Codable, Sendable {
    var blocked: Bool
    var watched: Bool
}

struct MemberProfile: Codable, Sendable {
    var username: String
    var website: String
    var company: String
    var companyTitle: String
    var location: String
    var tagline: String
    var bio: String
}
