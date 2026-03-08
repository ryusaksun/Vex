import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 400
                    }
                }
            )
            .clipped()
    }
}

struct SkeletonLine: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.fill.tertiary)
            .frame(width: width, height: height)
            .modifier(ShimmerModifier())
    }
}

struct TopicRowSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(.fill.tertiary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 8) {
                SkeletonLine(height: 16)
                SkeletonLine(width: 200, height: 12)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .modifier(ShimmerModifier())
    }
}

struct TopicDetailSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Circle()
                    .fill(.fill.tertiary)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonLine(width: 100, height: 14)
                    SkeletonLine(width: 80, height: 10)
                }
            }

            // Title
            SkeletonLine(height: 20)
            SkeletonLine(width: 250, height: 20)

            // Content
            SkeletonLine()
            SkeletonLine()
            SkeletonLine(width: 180)

            Divider()

            // Replies skeleton
            ForEach(0..<5, id: \.self) { _ in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(.fill.tertiary)
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonLine(width: 120, height: 12)
                        SkeletonLine()
                        SkeletonLine(width: 200)
                    }
                }
            }
        }
        .padding()
        .modifier(ShimmerModifier())
    }
}

struct TopicListSkeleton: View {
    var count: Int = 8

    var body: some View {
        ForEach(0..<count, id: \.self) { _ in
            TopicRowSkeleton()
            Divider()
        }
    }
}
