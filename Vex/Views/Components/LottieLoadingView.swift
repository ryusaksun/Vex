import Lottie
import SwiftUI

struct LottieLoadingView: View {
    var body: some View {
        LottieView {
            try await DotLottieFile.named("LoadingAnimation")
        }
        .looping()
        .frame(width: 120, height: 120)
    }
}
