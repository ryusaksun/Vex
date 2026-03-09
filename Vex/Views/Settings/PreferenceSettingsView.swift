import SwiftUI

struct PreferenceSettingsView: View {
    @EnvironmentObject private var settings: AppSettingsManager

    var body: some View {
        List {
            Section("显示") {
                Toggle("显示头像", isOn: $settings.showAvatar)
                Toggle("显示最后回复者", isOn: $settings.showLastReply)
            }

            Section("行为") {
                Toggle("应用内打开链接", isOn: $settings.openLinksInApp)
                Toggle("触觉反馈", isOn: $settings.hapticFeedback)
                Toggle("自动检测剪贴板", isOn: $settings.autoCheckClipboard)
            }

            Section {
                SecureField("Imgur Client-ID", text: $settings.imgurClientId)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("图床")
            } footer: {
                Text("使用 Imgur 匿名上传图片。前往 api.imgur.com 注册应用获取 Client-ID，上传的图片链接可在 V2EX 网页端自动显示为图片。")
            }

            if settings.isImageUploadConfigured {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("图床已配置，回复时可上传图片")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("偏好设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}
