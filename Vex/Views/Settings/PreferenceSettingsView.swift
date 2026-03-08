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
        }
        .navigationTitle("偏好设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}
