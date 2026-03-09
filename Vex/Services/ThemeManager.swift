import Foundation
import SwiftUI

@MainActor
final class ThemeManager: ObservableObject {
    @AppStorage("theme_mode") var themeMode: String = "system"
    @AppStorage("font_scale") var fontScale: Double = 1.0
    @AppStorage("accent_color") var accentColorName: String = "blue"
    @AppStorage("custom_accent_hex") var customAccentHex: String = ""

    var colorScheme: ColorScheme? {
        switch themeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var accentColor: Color {
        if accentColorName == "custom", let color = Color(hex: customAccentHex) {
            return color
        }
        return Self.presetColor(for: accentColorName) ?? .blue
    }

    /// 用于 ColorPicker 双向绑定
    var customColor: Color {
        get { Color(hex: customAccentHex) ?? .blue }
        set {
            customAccentHex = newValue.toHex()
            accentColorName = "custom"
        }
    }

    static let availableAccentColors: [(name: String, label: String, color: Color)] = [
        ("blue", "蓝色", .blue),
        ("red", "红色", .red),
        ("orange", "橙色", .orange),
        ("green", "绿色", .green),
        ("purple", "紫色", .purple),
        ("pink", "粉色", .pink),
        ("teal", "青色", .teal),
    ]

    static func presetColor(for name: String) -> Color? {
        availableAccentColors.first(where: { $0.name == name })?.color
    }
}

// MARK: - Color ↔ Hex

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let rgb = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    func toHex() -> String {
        let resolved = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
