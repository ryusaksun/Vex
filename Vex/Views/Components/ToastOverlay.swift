import SwiftUI

struct ToastOverlay: View {
    let toast: AlertManager.Toast

    var body: some View {
        HStack(spacing: 8) {
            icon
                .font(.body)

            Text(toast.message)
                .font(.subheadline)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal, 24)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private var icon: some View {
        switch toast.type {
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .info:
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
        case .loading:
            ProgressView()
                .controlSize(.small)
        }
    }
}

struct ToastModifier: ViewModifier {
    @Environment(AlertManager.self) private var alert

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = alert.currentToast {
                    ToastOverlay(toast: toast)
                        .padding(.top, 8)
                        .animation(.spring(duration: 0.3), value: alert.currentToast)
                        .onTapGesture {
                            alert.dismiss()
                        }
                }
            }
    }
}

extension View {
    func toastOverlay() -> some View {
        modifier(ToastModifier())
    }
}
