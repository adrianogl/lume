import AppKit
import SwiftUI

struct AlertBanner: View {
    let alert: NotchAlert
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.2)))

            VStack(alignment: .leading, spacing: 1) {
                Text(alert.title)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(alert.subtitle)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Palette.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if let title = alert.actionTitle, let url = alert.actionURL {
                Button {
                    NSWorkspace.shared.open(url)
                    onDismiss()
                } label: {
                    Text(title)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Metrics.earPadding + 4)
        .frame(height: AlertConfig.height)
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch alert.kind {
        case .failure: return "xmark"
        case .success: return "checkmark"
        case .info: return "arrow.triangle.branch"
        case .meeting: return "video.fill"
        case .attention: return "hand.raised.fill"
        }
    }

    private var tint: Color {
        switch alert.kind {
        case .failure: return Palette.redLight
        case .success, .meeting: return Palette.live
        case .info: return .white
        case .attention: return Palette.attention
        }
    }
}
