import AppKit
import SwiftUI

struct JoinButton: View {
    let url: URL
    var title = "Entrar"
    var isLarge = false
    @State private var isHovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "play.fill")
                    .font(.system(size: isLarge ? 9 : 7, weight: .bold))
                Text(title)
            }
            .font(.system(size: isLarge ? 12 : 11, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 6 / 255, green: 33 / 255, blue: 15 / 255))
            .padding(.horizontal, isLarge ? 12 : 9)
            .padding(.vertical, isLarge ? 5 : 2)
            .background(Capsule().fill(Palette.live.opacity(isHovering ? 1 : 0.92)))
            .fixedSize()
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(url.absoluteString)
    }
}
