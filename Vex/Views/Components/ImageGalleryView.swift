import Kingfisher
import SwiftUI

struct ImageGalleryView: View {
    let imageURLs: [URL]
    @State var selectedIndex: Int = 0

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedIndex) {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                    ZoomableImageView(url: url)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: imageURLs.count > 1 ? .automatic : .never))
            .background(.black)
            .ignoresSafeArea()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if imageURLs.indices.contains(selectedIndex) {
                        Menu {
                            Button {
                                saveImage()
                            } label: {
                                Label("保存图片", systemImage: "square.and.arrow.down")
                            }
                            ShareLink(item: imageURLs[selectedIndex])
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.white)
                        }
                    }
                }

                if imageURLs.count > 1 {
                    ToolbarItem(placement: .principal) {
                        Text("\(selectedIndex + 1) / \(imageURLs.count)")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func saveImage() {
        guard imageURLs.indices.contains(selectedIndex) else { return }
        let url = imageURLs[selectedIndex]
        Task {
            do {
                let result = try await KingfisherManager.shared.retrieveImage(with: url)
                UIImageWriteToSavedPhotosAlbum(result.image, nil, nil, nil)
            } catch {}
        }
    }
}

struct ZoomableImageView: View {
    let url: URL

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        KFImage(url)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        scale = lastScale * value.magnification
                    }
                    .onEnded { _ in
                        lastScale = max(1, scale)
                        if scale < 1 {
                            withAnimation { scale = 1 }
                            lastScale = 1
                        }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation {
                    if scale > 1 {
                        scale = 1
                        lastScale = 1
                    } else {
                        scale = 2
                        lastScale = 2
                    }
                }
            }
    }
}
