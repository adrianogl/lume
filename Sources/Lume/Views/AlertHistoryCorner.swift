import AppKit
import SwiftUI

struct AlertHistoryCorner: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if model.showsAlertHistory {
                AlertHistoryPanel(records: model.alertHistory)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
            }
            BellButton(unseen: model.unseenAlerts, isActive: model.showsAlertHistory) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    model.showsAlertHistory.toggle()
                }
            }
        }
    }
}

private struct BellButton: View {
    let unseen: Int
    let isActive: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: unseen > 0 ? "bell.badge.fill" : "bell.fill")
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isActive || isHovering ? Color.white : Color.white.opacity(0.75))
                .frame(width: 34, height: 34)
                .background(Circle().fill(isActive ? Palette.rowFillHover : Palette.rowFill))
                .overlay(alignment: .topTrailing) {
                    if unseen > 0 {
                        Text("\(unseen)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Capsule().fill(Palette.red))
                            .offset(x: 4, y: -4)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Avisos")
        .accessibilityLabel(unseen > 0 ? "Avisos, \(unseen) não vistos" : "Avisos")
    }
}

private struct AlertHistoryPanel: View {
    let records: [AlertRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Avisos")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
                Text(records.isEmpty ? "" : "\(records.count) recentes")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textMuted)
            }
            if records.isEmpty {
                Text("Nenhum aviso ainda. Avisos de PRs e reuniões aparecem aqui depois que passam pelo notch.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 6) {
                        ForEach(records) { AlertHistoryRow(record: $0) }
                    }
                }
                .scrollIndicators(.never)
                .frame(maxHeight: AlertHistoryConfig.panelMaxHeight)
            }
        }
        .padding(12)
        .frame(width: AlertHistoryConfig.panelWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 28 / 255, green: 24 / 255, blue: 27 / 255))
                .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        )
    }
}

private struct AlertHistoryRow: View {
    let record: AlertRecord

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint.opacity(0.18)))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(record.alert.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    Text(AgendaBuilder.clock(record.date))
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textMuted)
                }
                Text(record.alert.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if let url = record.alert.actionURL {
                JoinButton(url: url, title: record.alert.actionTitle ?? "Abrir")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.rowFill))
    }

    private var symbol: String {
        switch record.alert.kind {
        case .failure: return "xmark"
        case .success: return "checkmark"
        case .info: return "arrow.triangle.branch"
        case .meeting: return "video.fill"
        case .attention: return "hand.raised.fill"
        }
    }

    private var tint: Color {
        switch record.alert.kind {
        case .failure: return Palette.redLight
        case .success, .meeting: return Palette.live
        case .info: return .white
        case .attention: return Palette.attention
        }
    }
}
