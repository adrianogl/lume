import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                LogoView(size: 28)
                    .shadow(color: Palette.red.opacity(0.6), radius: 8)
                Text("lume")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)

            Text("CATEGORIAS")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Palette.textMuted)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            ForEach(model.categories) { category in
                SidebarRow(category: category, isActive: category.id == model.activeID) {
                    model.activeID = category.id
                }
            }

            Spacer(minLength: 14)

            if let playing = model.nowPlaying {
                NowPlayingCard(playing: playing) { model.onMusicCommand?($0) }
            }
        }
        .frame(width: Metrics.sidebarWidth, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct SidebarRow: View {
    let category: LumeCategory
    let isActive: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.symbol)
                    .frame(width: 16)
                Text(category.name)
                Spacer(minLength: 4)
                if let badge = category.badge {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isActive ? Color.white : Palette.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(isActive ? 0.18 : 0.08)))
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? Color.white.opacity(0.16) : Color.white.opacity(isHovering ? 0.07 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
