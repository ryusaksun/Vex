import Foundation
import UIKit

/// 基于 Imgur 匿名 API 的图片上传
enum ImageUploader {
    struct Config {
        let clientId: String

        var isValid: Bool {
            !clientId.isEmpty
        }
    }

    /// 上传图片到 Imgur，返回图片 URL（i.imgur.com 域名，V2EX 原生格式自动嵌入）
    static func upload(image: UIImage, config: Config) async throws -> String {
        guard config.isValid else {
            throw UploadError.notConfigured
        }

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw UploadError.compressionFailed
        }

        let boundary = UUID().uuidString
        let url = URL(string: "https://api.imgur.com/3/image")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Client-ID \(config.clientId)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // 构建 multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"upload.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, httpResponse) = try await URLSession.shared.data(for: request)

        guard let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode else {
            throw UploadError.uploadFailed("无法获取响应状态")
        }

        guard statusCode == 200 else {
            let message = String(data: responseData, encoding: .utf8) ?? "未知错误"
            throw UploadError.uploadFailed("HTTP \(statusCode): \(message)")
        }

        // 解析 JSON: { "data": { "link": "https://i.imgur.com/xxx.jpg" } }
        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let jsonData = json["data"] as? [String: Any],
              let link = jsonData["link"] as? String else {
            throw UploadError.uploadFailed("无法解析返回数据")
        }

        // Imgur 返回的 link 可能是 http，统一换成 https
        if link.hasPrefix("http://") {
            return "https://" + link.dropFirst("http://".count)
        }
        return link
    }

    enum UploadError: LocalizedError {
        case notConfigured
        case compressionFailed
        case uploadFailed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: "未配置图床，请在设置中填写 Imgur Client-ID"
            case .compressionFailed: "图片压缩失败"
            case .uploadFailed(let msg): "上传失败：\(msg)"
            }
        }
    }
}
