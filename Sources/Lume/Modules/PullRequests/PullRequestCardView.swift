import SwiftUI

struct PullRequestCardView: View {
    @ObservedObject var monitor: PullRequestMonitor

    var body: some View {
        TimelineView(.periodic(from: .now, by: PRLayout.refresh)) { timeline in
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: PRLayout.symbol)
                        .font(.system(size: PRLayout.symbolSize, weight: .semibold))
                    Text(PRText.title).font(.system(size: WeekLayout.titleSize, weight: .semibold))
                    Spacer(minLength: 0)
                    if monitor.loadState == .ready {
                        Text(PRText.attention(monitor.attentionCount))
                            .font(.system(size: WeekLayout.metaSize, weight: monitor.attentionCount > 0 ? .semibold : .regular))
                            .foregroundStyle(monitor.attentionCount > 0 ? NotchRim.amber : .white.opacity(WeekLayout.secondaryOpacity))
                    }
                }
                .padding(.top, WeekLayout.headerTop)
                .padding(.bottom, 6)

                content(now: timeline.date)
            }
            .padding(.horizontal, WeekLayout.horizontalPadding)
            .padding(.bottom, PRLayout.itemVerticalPadding * 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear(perform: monitor.refreshIfStale)
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        switch monitor.loadState {
        case .ready where !monitor.items.isEmpty:
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(monitor.items.enumerated()), id: \.element.id) { index, pr in
                        if index > 0 {
                            Rectangle().fill(.white.opacity(PRLayout.dividerOpacity)).frame(height: 1)
                        }
                        PullRequestRow(pr: pr, now: now)
                    }
                }
            }
            .mask(LinearGradient(
                stops: [.init(color: .black, location: PRLayout.fadeStart), .init(color: .clear, location: 1)],
                startPoint: .top,
                endPoint: .bottom
            ))
        default:
            Text(message)
                .font(.system(size: WeekLayout.rowSize))
                .opacity(WeekLayout.secondaryOpacity)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
        }
    }

    private var message: String {
        switch monitor.loadState {
        case .idle, .loading: PRText.loading
        case .missingCLI: PRText.missingCLI
        case .notLoggedIn: PRText.notLoggedIn
        case .failed(let error): PRText.failedPrefix + error
        case .ready: PRText.empty
        }
    }
}

private struct PullRequestRow: View {
    let pr: PullRequest
    let now: Date

    var body: some View {
        let state = pr.state
        VStack(alignment: .leading, spacing: PRLayout.itemSpacing) {
            HStack(spacing: 8) {
                Text(state.tag)
                    .font(.system(size: PRLayout.tagSize, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(state.color)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(RoundedRectangle(cornerRadius: 4).fill(state.color.opacity(0.18)))
                Text(pr.title)
                    .font(.system(size: PRLayout.titleSize, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(PRText.ago(from: pr.updatedAt, to: now))
                    .font(.system(size: PRLayout.metaSize))
                    .monospacedDigit()
                    .opacity(0.4)
                OpenButton(state: state) { PullRequestMonitor.open(pr) }
            }
            locationLine
            statusLine
        }
        .padding(.vertical, PRLayout.itemVerticalPadding)
        .padding(.horizontal, 2)
        .opacity(state.needsYou || state == .approved ? 1 : PRLayout.dimOpacity)
    }

    private var locationLine: some View {
        var parts: [Text] = [Text(PRText.number(pr))]
        if !pr.isMine { parts.append(Text(PRText.author(pr.author))) }
        parts.append(Text("\(pr.headBranch) \(PRText.arrow) \(pr.baseBranch)"))
        parts.append(
            Text("+\(pr.additions)").foregroundColor(PRLayout.ok)
            + Text(" ")
            + Text("−\(pr.deletions)").foregroundColor(PRLayout.failed)
            + Text(" " + PRText.size(pr))
        )
        if pr.isMine {
            parts.append(pr.hasConflict ? Text(PRText.conflict).foregroundColor(PRLayout.failed) : Text(PRText.noConflict))
        }
        return joined(parts)
    }

    private var statusLine: some View {
        HStack(spacing: 6) {
            joined(checkParts)
            separator
            if !pr.approvedBy.isEmpty {
                Avatars(logins: pr.approvedBy)
                Text(PRText.approvals(pr.approvedBy.count))
            } else if !pr.changesBy.isEmpty {
                Avatars(logins: pr.changesBy)
                Text(PRText.changesBy(pr.changesBy.count))
            } else {
                Text(reviewText)
            }
            if let comment = pr.lastComment, !comment.body.isEmpty {
                separator
                Text(PRText.comment(comment))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .font(.system(size: PRLayout.metaSize))
        .foregroundStyle(.white.opacity(WeekLayout.secondaryOpacity))
        .lineLimit(1)
    }

    private var reviewText: String {
        if !pr.isMine { return PRText.requestedToYou(others: max(pr.pendingReviewers - 1, 0)) }
        return pr.pendingReviewers > 0 ? PRText.requested(pr.pendingReviewers) : PRText.noReview
    }

    private var checkParts: [Text] {
        let checks = pr.checks
        guard checks.total > 0 else { return [Text(PRText.noChecks)] }
        var parts: [Text] = []
        if let first = checks.failedNames.first {
            parts.append(Text(PRText.failedCheck(first, others: checks.failedNames.count - 1)).foregroundColor(PRLayout.failed))
        }
        if checks.running > 0 {
            parts.append(Text(PRText.running(checks.running)).foregroundColor(NotchRim.amber))
        }
        if checks.passed > 0 || parts.isEmpty {
            parts.append(Text(PRText.passed(checks.passed, of: checks.total)).foregroundColor(PRLayout.ok))
        }
        return parts
    }

    private var separator: some View {
        Text(PRText.separator).foregroundStyle(.white.opacity(PRLayout.separatorOpacity))
    }

    private func joined(_ parts: [Text]) -> some View {
        let sep = Text("  \(PRText.separator)  ").foregroundColor(.white.opacity(PRLayout.separatorOpacity))
        let text = parts.dropFirst().reduce(parts.first ?? Text("")) { $0 + sep + $1 }
        return text
            .font(.system(size: PRLayout.metaSize))
            .foregroundStyle(.white.opacity(WeekLayout.secondaryOpacity))
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

private struct OpenButton: View {
    let state: PRState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(PRText.open)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(state.needsYou ? Color.black : Color.white)
                .padding(.horizontal, 9)
                .frame(height: 18)
                .background(Capsule().fill(background))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        if state == .readyToMerge { return PRLayout.mergeButton }
        return state.needsYou ? .white : .white.opacity(0.14)
    }
}

private struct Avatars: View {
    let logins: [String]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(logins.prefix(PRLayout.maxAvatars), id: \.self) { login in
                Text(String(login.prefix(2)).uppercased())
                    .font(.system(size: PRLayout.avatarFontSize, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: PRLayout.avatarSize, height: PRLayout.avatarSize)
                    .background(Circle().fill(color(for: login)))
            }
        }
    }

    private func color(for login: String) -> Color {
        let sum = login.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return PRLayout.avatarColors[sum % PRLayout.avatarColors.count]
    }
}
