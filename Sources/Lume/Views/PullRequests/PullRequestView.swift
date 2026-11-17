import AppKit
import SwiftUI

struct PullRequestView: View {
    @ObservedObject var store: PullRequestStore
    @State private var tab: PRTab = .mine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            HStack(spacing: 8) {
                PRTile(label: "Para revisar", value: store.review.count)
                PRTile(label: "CI falhando", value: store.failingCI, color: store.failingCI > 0 ? Palette.redLight : .white)
                PRTile(label: "Com comentários", value: store.withComments)
                PRTile(label: "Prontos para merge", value: store.ready.count, color: store.ready.isEmpty ? .white : Palette.live)
            }
            tabs
            if let error = store.error, store.lastRefresh == nil {
                EmptyRow(text: error)
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 6) {
                        let items = store.items(for: tab)
                        if items.isEmpty {
                            EmptyRow(text: store.lastRefresh == nil ? "Carregando PRs…" : emptyText)
                        }
                        ForEach(items) { PRRow(pr: $0, showsAuthor: tab == .review) }
                    }
                }
                .scrollIndicators(.never)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("PRs")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Spacer()
            Text(store.isRefreshing && store.lastRefresh == nil ? "carregando…" : Format.relative(store.lastRefresh))
                .font(.system(size: 12))
                .foregroundStyle(Palette.textMuted)
            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Palette.rowFill))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(store.isRefreshing ? 0.3 : 0.85))
            .disabled(store.isRefreshing)
            .help("Atualizar agora")
        }
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            TabChip(title: "Meus PRs", count: store.mine.count, isSelected: tab == .mine) { tab = .mine }
            TabChip(title: "Revisar", count: store.review.count, isSelected: tab == .review) { tab = .review }
            Spacer()
            TabChip(title: "Prontos para merge", count: store.ready.count, isSelected: tab == .ready, dot: Palette.live) { tab = .ready }
        }
    }

    private var emptyText: String {
        switch tab {
        case .mine: return "Nenhum PR seu aberto"
        case .review: return "Nenhum review pedido a você"
        case .ready: return "Nenhum PR pronto para merge"
        }
    }
}

private struct PRTile: View {
    let label: String
    let value: Int
    var color: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Palette.textMuted)
                .lineLimit(1)
            Text("\(value)")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.rowFill))
    }
}

private struct TabChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    var dot: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dot {
                    Circle().fill(dot).frame(width: 6, height: 6)
                }
                Text(title)
                Text("\(count)")
                    .monospacedDigit()
                    .opacity(0.7)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(isSelected ? Color.white.opacity(0.16) : .clear))
            .foregroundStyle(isSelected ? Color.white : Palette.textMuted)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct PRRow: View {
    let pr: PullRequest
    let showsAuthor: Bool
    @State private var isHovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(pr.url)
        } label: {
            HStack(spacing: 10) {
                CIBadge(state: pr.ci)
                VStack(alignment: .leading, spacing: 1) {
                    Text(pr.title)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    Text(meta)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.textMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    if pr.approvals > 0 { Pill(text: "✓ \(pr.approvals)", style: .positive) }
                    if pr.changesRequested { Pill(text: "alterações", style: .negative) }
                    if pr.comments > 0 { Pill(text: "\(pr.comments)", symbol: "bubble.left", style: .neutral) }
                    if pr.hasConflict { Pill(text: "conflito", style: .negative) }
                    if pr.isDraft { Pill(text: "rascunho", style: .muted) }
                    if pr.isReadyToMerge { Pill(text: "pronto para merge", style: .ready) }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovering ? Palette.rowFillHover : Palette.rowFill)
            )
            .overlay(alignment: .leading) {
                if pr.isReadyToMerge {
                    Capsule().fill(Palette.live).frame(width: 2.5).padding(.vertical, 8)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(pr.url.absoluteString)
    }

    private var meta: String {
        var parts = ["\(pr.repository) #\(pr.number)"]
        if showsAuthor, !pr.author.isEmpty { parts.append("por \(pr.author)") }
        parts.append(PRFormat.relative(pr.updatedAt))
        return parts.joined(separator: " · ")
    }
}

private struct CIBadge: View {
    let state: CIState
    @State private var isSpinning = false

    var body: some View {
        Group {
            switch state {
            case .pass:
                symbol("checkmark", color: Palette.live)
            case .fail:
                symbol("xmark", color: Palette.redLight)
            case .running:
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(PRColors.amber, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isSpinning)
                    .onAppear { isSpinning = true }
            case .none:
                Circle().fill(Color.white.opacity(0.15)).frame(width: 8, height: 8)
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityLabel(accessibilityText)
    }

    private func symbol(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(color)
            .frame(width: 18, height: 18)
            .background(Circle().fill(color.opacity(0.18)))
    }

    private var accessibilityText: String {
        switch state {
        case .pass: return "CI passou"
        case .fail: return "CI falhou"
        case .running: return "CI rodando"
        case .none: return "Sem CI"
        }
    }
}

private struct Pill: View {
    enum Style { case positive, negative, neutral, muted, ready }

    let text: String
    var symbol: String? = nil
    let style: Style

    var body: some View {
        HStack(spacing: 3) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 9, weight: .semibold))
            }
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .foregroundStyle(foreground)
        .background(Capsule().fill(background))
    }

    private var foreground: Color {
        switch style {
        case .positive: return Palette.live
        case .negative: return Palette.redLight
        case .neutral: return .white.opacity(0.75)
        case .muted: return Palette.textMuted
        case .ready: return Color(red: 6 / 255, green: 33 / 255, blue: 15 / 255)
        }
    }

    private var background: Color {
        switch style {
        case .positive: return Palette.live.opacity(0.14)
        case .negative: return Palette.redLight.opacity(0.16)
        case .neutral, .muted: return Color.white.opacity(0.08)
        case .ready: return Palette.live
        }
    }
}

private struct EmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Palette.textMuted)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.rowFill))
    }
}

private enum PRColors {
    static let amber = Color(red: 242 / 255, green: 184 / 255, blue: 75 / 255)
}

enum PRFormat {
    static func relative(_ date: Date) -> String {
        let minutes = Int(-date.timeIntervalSinceNow / 60)
        if minutes < 1 { return "agora" }
        if minutes < 60 { return "há \(minutes) min" }
        let hours = minutes / 60
        if hours < 24 { return "há \(hours) h" }
        let days = hours / 24
        return days == 1 ? "ontem" : "há \(days) dias"
    }
}
