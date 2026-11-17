import SwiftUI

struct EarsView: View {
    @ObservedObject var model: NotchModel

    private var playing: NowPlaying? {
        guard !model.isOpen, let playing = model.nowPlaying, playing.isPlaying else { return nil }
        return playing
    }

    var body: some View {
        HStack(spacing: 0) {
            leftEar
                .frame(width: Metrics.earWidth, alignment: .leading)
            Spacer(minLength: 0)
            center
                .frame(width: model.notchSize.width)
            Spacer(minLength: 0)
            VoiceIndicatorView(state: model.voice)
                .frame(width: Metrics.earWidth, alignment: .trailing)
        }
        .padding(.horizontal, model.isOpen ? Metrics.openEarPadding : Metrics.earPadding)
        .frame(height: model.notchSize.height)
        .contentShape(Rectangle())
        .onTapGesture { model.togglePin() }
        .animation(.easeInOut(duration: 0.25), value: model.nowPlaying)
    }

    @ViewBuilder
    private var center: some View {
        if !model.hasPhysicalNotch, let playing {
            MusicLabel(playing: playing)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var leftEar: some View {
        if model.hasPhysicalNotch, let playing {
            MusicLabel(playing: playing)
        } else if let ear = model.ear, let live = ear.live {
            LiveEarView(live: live, title: ear.earText, joinURL: ear.joinURL)
        } else if let ear = model.ear {
            HStack(spacing: 6) {
                Image(systemName: ear.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.redLight)
                if let lead = ear.earLead {
                    Text(lead)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.redLight)
                        .fixedSize()
                }
                Text(ear.earText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                if let url = ear.joinURL {
                    JoinButton(url: url)
                }
            }
        }
    }
}

private struct MusicLabel: View {
    let playing: NowPlaying

    var body: some View {
        HStack(spacing: 8) {
            ArtworkView(url: playing.artworkURL)
                .frame(width: 18, height: 18)
            Text(playing.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 6)
    }
}
