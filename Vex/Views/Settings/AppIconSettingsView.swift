import SwiftUI

struct AppIconSettingsView: View {
    @State private var currentIcon: String?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    // (iconName for setAlternateIconName, display label, preview asset name)
    private static let iconData: [(String, String, String)] = [
        ("", "默认", "AppIconDefaultPreview"),
        ("AppIconSharp", "锐利", "AppIconSharpPreview"),
        ("AppIconRounded", "圆润", "AppIconRoundedPreview"),
        ("AppIconNeon", "霓虹", "AppIconNeonPreview"),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(Array(Self.iconData.enumerated()), id: \.offset) { _, item in
                    let actualName: String? = item.0.isEmpty ? nil : item.0
                    let label = item.1
                    let preview = item.2
                    let isSelected = currentIcon == actualName
                    Button {
                        setIcon(actualName)
                    } label: {
                        VStack(spacing: 8) {
                            Image(preview)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                                )
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                            HStack(spacing: 4) {
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.accentColor)
                                }
                                Text(label)
                                    .font(.subheadline)
                                    .fontWeight(isSelected ? .semibold : .regular)
                            }
                            .foregroundStyle(isSelected ? Color.accentColor : .primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("应用图标")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            currentIcon = UIApplication.shared.alternateIconName
        }
    }

    private func setIcon(_ name: String?) {
        guard name != currentIcon else { return }
        UIApplication.shared.setAlternateIconName(name) { error in
            if error == nil {
                currentIcon = name
                HapticManager.notification(.success)
            }
        }
    }
}
