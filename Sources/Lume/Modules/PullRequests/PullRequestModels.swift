import SwiftUI

enum PRState: Int, Comparable {
    case ciFailed, readyToMerge, changesRequested, conflict, reviewRequested, approved, waiting, draft

    static func < (lhs: PRState, rhs: PRState) -> Bool { lhs.rawValue < rhs.rawValue }

    var needsYou: Bool { self <= .reviewRequested }

    var tag: String {
        switch self {
        case .ciFailed: "CI falhou"
        case .readyToMerge: "merge"
        case .changesRequested: "mudanças"
        case .conflict: "conflito"
        case .reviewRequested: "review"
        case .approved: "aprovada"
        case .waiting: "aguardando"
        case .draft: "rascunho"
        }
    }

    var color: Color {
        switch self {
        case .ciFailed, .conflict: PRLayout.failed
        case .readyToMerge, .approved: PRLayout.ok
        case .changesRequested: PRLayout.changes
        case .reviewRequested: NotchRim.amber
        case .waiting, .draft: .white
        }
    }

    var alertTitle: String {
        switch self {
        case .ciFailed: "CI falhou"
        case .readyToMerge: "Pronta para merge"
        case .changesRequested: "Pediram mudanças"
        case .conflict: "PR com conflito"
        case .reviewRequested: "Pediram seu review"
        case .approved: "Aprovada"
        case .waiting, .draft: ""
        }
    }

    var alertSymbol: String {
        switch self {
        case .ciFailed, .conflict: "xmark"
        case .readyToMerge, .approved: "checkmark"
        case .changesRequested: "text.bubble"
        default: PRLayout.symbol
        }
    }
}

struct PRChecks: Equatable {
    var total = 0
    var passed = 0
    var running = 0
    var failedNames: [String] = []
}

struct PRComment: Equatable {
    let author: String
    let body: String
}

struct PullRequest: Identifiable, Equatable {
    let url: URL
    let number: Int
    let title: String
    let repository: String
    let author: String
    let isMine: Bool
    let isDraft: Bool
    let isBot: Bool
    let headBranch: String
    let baseBranch: String
    let additions: Int
    let deletions: Int
    let changedFiles: Int
    let hasConflict: Bool
    let isClean: Bool
    let reviewDecision: String
    let approvedBy: [String]
    let changesBy: [String]
    let pendingReviewers: Int
    let checks: PRChecks
    let lastComment: PRComment?
    let updatedAt: Date

    var id: URL { url }

    var state: PRState {
        if isDraft { return .draft }
        guard isMine else { return .reviewRequested }
        if !checks.failedNames.isEmpty { return .ciFailed }
        if reviewDecision == "APPROVED", isClean { return .readyToMerge }
        if reviewDecision == "CHANGES_REQUESTED" { return .changesRequested }
        if hasConflict { return .conflict }
        if reviewDecision == "APPROVED" { return .approved }
        return .waiting
    }
}

struct PRAlert: Identifiable, Equatable {
    let id = UUID()
    let state: PRState
    let pullRequest: PullRequest

    var subtitle: String {
        let pr = pullRequest
        var parts = [PRText.number(pr)]
        if !pr.isMine { parts.append(PRText.author(pr.author)) }
        return parts.joined(separator: " · ")
    }
}

enum PRLoadState: Equatable {
    case idle
    case loading
    case missingCLI
    case notLoggedIn
    case failed(String)
    case ready
}
