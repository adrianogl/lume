import SwiftUI

struct ArtworkView: View {
    let url: URL?
    var cornerRadius: CGFloat = 4

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Palette.red.opacity(0.35)
                    Image(systemName: "music.note")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}
