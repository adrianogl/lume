import SwiftUI

struct NowPlayingCard: View {
    let playing: NowPlaying
    let onCommand: (MusicCommand) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ArtworkView(url: playing.artworkURL, cornerRadius: 0)

            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.55), .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 8) {
                VStack(spacing: 1) {
                    Text(playing.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    Text(playing.artist)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)

                HStack(spacing: 10) {
                    ControlButton(symbol: "backward.fill", label: "Faixa anterior") { onCommand(.previous) }
                    ControlButton(
                        symbol: playing.isPlaying ? "pause.fill" : "play.fill",
                        label: playing.isPlaying ? "Pausar" : "Tocar",
                        isPrimary: true
                    ) { onCommand(.playPause) }
                    ControlButton(symbol: "forward.fill", label: "Próxima faixa") { onCommand(.next) }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .frame(width: Metrics.sidebarWidth, height: Metrics.sidebarWidth)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1))
        )
    }
}

private struct ControlButton: View {
    let symbol: String
    let label: String
    var isPrimary = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: isPrimary ? 12 : 10, weight: .bold))
                .foregroundStyle(isPrimary ? Color.black : Color.white.opacity(isHovering ? 1 : 0.85))
                .frame(width: isPrimary ? 30 : 26, height: isPrimary ? 30 : 26)
                .background(
                    Circle().fill(isPrimary ? Color.white.opacity(isHovering ? 1 : 0.92) : Color.white.opacity(isHovering ? 0.2 : 0.1))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(label)
    }
}
