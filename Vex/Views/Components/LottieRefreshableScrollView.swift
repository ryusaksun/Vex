import Lottie
import SwiftUI

struct LottieRefreshableScrollView<Content: View>: View {
    let onRefresh: () async -> Void
    @ViewBuilder let content: () -> Content

    @State private var isRefreshing = false
    @State private var showAnimation = false

    private let threshold: CGFloat = 80

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 下拉刷新动画区域
                ZStack {
                    if showAnimation || isRefreshing {
                        LottieView {
                            try await DotLottieFile.named("RefreshAnimation")
                        }
                        .looping()
                        .frame(width: 120, height: 120)
                        .transition(.opacity)
                    }
                }
                .frame(height: showAnimation || isRefreshing ? 130 : 0)
                .clipped()

                content()
            }
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.frame(in: .named("lottieRefreshScroll")).minY > threshold
            } action: { isPastThreshold in
                guard !isRefreshing else { return }
                if isPastThreshold {
                    showAnimation = true
                } else if showAnimation {
                    // 手指松开后 offset 回弹低于阈值，触发刷新
                    triggerRefresh()
                }
            }
        }
        .coordinateSpace(.named("lottieRefreshScroll"))
    }

    private func triggerRefresh() {
        isRefreshing = true
        Task {
            await onRefresh()
            withAnimation(.easeOut(duration: 0.3)) {
                isRefreshing = false
                showAnimation = false
            }
        }
    }
}
