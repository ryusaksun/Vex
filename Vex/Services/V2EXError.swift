import Foundation

enum V2EXError: LocalizedError {
    case authRequired
    case restricted
    case twoFactorRequired(once: String, problems: [String]?)
    case resourceNotFound
    case unexpectedResponse(String)
    case formProblems([String])
    case cooldown
    case memberLocked
    case notAllowed
    case editNotAllowed
    case dailySigned
    case twoFactorVerifyFailed(once: String, problems: [String]?)
    case loginError([String])
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .authRequired:
            return "需要登录"
        case .restricted:
            return "访问受限"
        case .twoFactorRequired:
            return "需要两步验证"
        case .resourceNotFound:
            return "资源不存在"
        case .unexpectedResponse(let msg):
            return "意外的响应: \(msg)"
        case .formProblems(let problems):
            return problems.joined(separator: "\n")
        case .cooldown:
            return "操作过于频繁，请稍后再试"
        case .memberLocked:
            return "该用户已被锁定"
        case .notAllowed:
            return "无权执行此操作"
        case .editNotAllowed:
            return "无法编辑"
        case .dailySigned:
            return "今日已签到"
        case .twoFactorVerifyFailed(_, let problems):
            return problems?.joined(separator: "\n") ?? "验证码错误"
        case .loginError(let problems):
            return problems.joined(separator: "\n")
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}
