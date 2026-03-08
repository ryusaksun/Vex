import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        List {
            Section("主题模式") {
                Picker("外观", selection: $theme.themeMode) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("强调色") {
                let colors = ThemeManager.availableAccentColors
                ForEach(0..<colors.count, id: \.self) { index in
                    let item = colors[index]
                    Button {
                        theme.accentColorName = item.name
                    } label: {
                        HStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 24, height: 24)
                            Text(item.label)
                                .foregroundStyle(.primary)
                            Spacer()
                            if theme.accentColorName == item.name {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }

            Section("字体大小") {
                HStack {
                    Text("A")
                        .font(.caption)
                    Slider(value: $theme.fontScale, in: 0.8...1.4, step: 0.1)
                    Text("A")
                        .font(.title3)
                }

                Text("预览文字 - Preview Text")
                    .font(.system(size: 16 * theme.fontScale))
            }
        }
        .navigationTitle("主题设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}
