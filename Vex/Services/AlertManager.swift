import Foundation
import Observation

@Observable
@MainActor
final class AlertManager {
    struct Toast: Equatable {
        enum ToastType {
            case success, error, info, loading
        }
        let id = UUID()
        let type: ToastType
        let message: String
        var duration: TimeInterval

        static func == (lhs: Toast, rhs: Toast) -> Bool {
            lhs.id == rhs.id
        }
    }

    var currentToast: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ type: Toast.ToastType, _ message: String, duration: TimeInterval = 2.0) {
        dismissTask?.cancel()
        currentToast = Toast(type: type, message: message, duration: duration)

        if type != .loading {
            dismissTask = Task {
                try? await Task.sleep(for: .seconds(duration))
                if !Task.isCancelled {
                    currentToast = nil
                }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        currentToast = nil
    }
}
