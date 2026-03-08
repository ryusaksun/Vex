import Foundation
import SwiftUI

@MainActor
final class ThemeManager: ObservableObject {
    @AppStorage("theme_mode") var themeMode: String = "system"
    @AppStorage("font_scale") var fontScale: Double = 1.0
    @AppStorage("accent_color") var accentColorName: String = "blue"

    var colorScheme: ColorScheme? {
        switch themeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var accentColor: Color {
        switch accentColorName {
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        default: return .blue
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
}
