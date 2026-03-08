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
                Link(destination: URL(string: "https://github.com/Ryusaksun/Vex")!) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Link(destination: URL(string: "https://www.v2ex.com")!) {
                    Label("V2EX", systemImage: "globe")
                }
            }

            Section("致谢") {
                Label("SwiftSoup", systemImage: "doc.text")
                Label("Kingfisher", systemImage: "photo")
                Label("MarkdownUI", systemImage: "text.badge.checkmark")
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
