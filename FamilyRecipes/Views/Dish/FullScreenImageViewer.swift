import SwiftUI

struct FullScreenImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let imageData: Data?
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        ZStack {
            // Immersive black background
            Color.black
                .ignoresSafeArea()
            
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Only allow dragging to move when zoomed in, or drag down to dismiss
                                if scale > 1.0 {
                                    offset = value.translation
                                } else {
                                    offset = CGSize(width: 0, height: value.translation.height)
                                }
                            }
                            .onEnded { value in
                                if scale == 1.0 && abs(value.translation.height) > 100 {
                                    // Swipe down/up to dismiss
                                    dismiss()
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        offset = .zero
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if scale > 1.0 {
                                scale = 1.0
                            } else {
                                scale = 2.2
                            }
                        }
                    }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("无法加载图片")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            // Immersive Floating Close Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                            .padding(20)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
        .statusBarHidden(true)
    }
}
