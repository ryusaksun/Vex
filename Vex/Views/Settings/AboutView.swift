import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.accentColor)

                    Text("Vex")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("第三方 V2EX 客户端")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("版本 \(appVersion) (\(buildNumber))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            Section {
                Link(destination: feedbackURL) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Bug 反馈", systemImage: "ladybug")
                        Text("ryusaksun@outlook.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var feedbackURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "ryusaksun@outlook.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Vex Bug 反馈"),
            URLQueryItem(name: "body", value: "版本：\(appVersion) (\(buildNumber))\n\n问题描述：\n")
        ]
        return components.url ?? URL(string: "mailto:ryusaksun@outlook.com")!
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
