import Foundation
import SwiftUI

@MainActor
final class AppSettingsManager: ObservableObject {
    @AppStorage("show_avatar") var showAvatar: Bool = true
    @AppStorage("show_last_reply") var showLastReply: Bool = true
    @AppStorage("open_links_in_app") var openLinksInApp: Bool = true
    @AppStorage("haptic_feedback") var hapticFeedback: Bool = true
    @AppStorage("auto_check_clipboard") var autoCheckClipboard: Bool = true
}
