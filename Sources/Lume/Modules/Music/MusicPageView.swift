import SwiftUI

struct MusicPageView: View {
    @ObservedObject var music: MusicController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(MusicText.title).font(.system(size: WeekLayout.titleSize, weight: .semibold))
                Spacer(minLength: 0)
                if let app = music.nowPlaying?.app {
                    HStack(spacing: 5) {
                        Circle().fill(app.color).frame(width: 7, height: 7)
                        Text(app.displayName)
                    }
                    .font(.system(size: WeekLayout.metaSize))
                    .opacity(WeekLayout.secondaryOpacity)
                }
            }
            .padding(.top, WeekLayout.headerTop)

            if let track = music.nowPlaying {
                player(track)
                    .padding(.top, MusicLayout.playerTop)
            } else {
                Text(MusicText.nothing)
                    .font(.system(size: WeekLayout.rowSize))
                    .opacity(WeekLayout.secondaryOpacity)
                    .padding(.top, 24)
            }
        }
        .padding(.horizontal, WeekLayout.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func player(_ track: NowPlaying) -> some View {
        HStack(alignment: .top, spacing: MusicLayout.coverSpacing) {
            cover(track)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: MusicLayout.titleSize, weight: .bold))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: WeekLayout.metaSize))
                    .opacity(WeekLayout.secondaryOpacity)
                    .lineLimit(1)
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    ProgressRow(track: track, now: timeline.date)
                }
                .padding(.top, 6)
                HStack(spacing: MusicLayout.controlSpacing) {
                    ControlButton(symbol: "backward.fill", label: MusicText.previous) { music.send(.previous) }
                    ControlButton(symbol: track.isPlaying ? "pause.fill" : "play.fill", label: track.isPlaying ? MusicText.pause : MusicText.play, size: 15) {
                        music.send(.playPause)
                    }
                    ControlButton(symbol: "forward.fill", label: MusicText.next) { music.send(.next) }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func cover(_ track: NowPlaying) -> some View {
        let shape = RoundedRectangle(cornerRadius: MusicLayout.coverRadius)
        Group {
            if let artwork = track.artwork {
                Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
            } else {
                shape.fill(LinearGradient(colors: [NotchRim.coral, NotchRim.magenta], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Image(systemName: "music.note").font(.system(size: 22, weight: .semibold)).opacity(0.8))
            }
        }
        .frame(width: MusicLayout.coverSize, height: MusicLayout.coverSize)
        .clipShape(shape)
    }
}

private struct ProgressRow: View {
    let track: NowPlaying
    let now: Date

    var body: some View {
        let position = track.position(at: now)
        let fraction = track.duration.map { $0 > 0 ? position / $0 : 0 } ?? 0
        HStack(spacing: 8) {
            Text(MusicText.time(position))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule().fill(.white).frame(width: proxy.size.width * min(max(fraction, 0), 1))
                }
            }
            .frame(height: 4)
            Text(track.duration.map(MusicText.time) ?? "")
        }
        .font(.system(size: 10))
        .monospacedDigit()
        .foregroundStyle(.white.opacity(0.5))
    }
}

private struct ControlButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 12
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
