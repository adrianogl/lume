import SwiftUI

enum PRLayout {
    static let openSize = CGSize(width: 560, height: 360)
    static let refresh: TimeInterval = 30
    static let itemSpacing: CGFloat = 4
    static let itemVerticalPadding: CGFloat = 10
    static let titleSize: CGFloat = 11.5
    static let metaSize: CGFloat = 10
    static let tagSize: CGFloat = 8
    static let avatarSize: CGFloat = 13
    static let avatarFontSize: CGFloat = 7
    static let dividerOpacity: Double = 0.1
    static let separatorOpacity: Double = 0.22
    static let dimOpacity: Double = 0.55
    static let fadeStart: CGFloat = 0.88
    static let symbol = "arrow.triangle.pull"
    static let symbolSize: CGFloat = 11
    static let countSize: CGFloat = 10.5
    static let countWidth: CGFloat = 9
    static let alertIconSize: CGFloat = 30
    static let alertGlyphSize: CGFloat = 14
    static let ok = Color(red: 79 / 255, green: 224 / 255, blue: 122 / 255)
    static let failed = Color(red: 1, green: 122 / 255, blue: 107 / 255)
    static let changes = Color(red: 1, green: 111 / 255, blue: 160 / 255)
    static let mergeButton = Color(red: 48 / 255, green: 199 / 255, blue: 89 / 255)
    static let avatarColors: [Color] = [
        Color(red: 143 / 255, green: 180 / 255, blue: 1),
        Color(red: 1, green: 207 / 255, blue: 138 / 255),
        Color(red: 201 / 255, green: 167 / 255, blue: 1),
        Color(red: 143 / 255, green: 227 / 255, blue: 166 / 255),
        Color(red: 1, green: 160 / 255, blue: 180 / 255)
    ]
    static let maxAvatars = 3
    static let quoteLength = 70
}

enum PRPolling {
    static let choices = [1, 2, 5, 10]
    static let staleAfter: TimeInterval = 30
    static let ghCandidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
    static let resultLimit = 30
    static let checksLimit = 60
    static let authHint = "auth login"
}

enum PRQuery {
    static func searches(organizations: [String]) -> (mine: String, review: String) {
        let scope = organizations
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { $0.contains("/") ? "repo:\($0)" : "org:\($0)" }
            .joined(separator: " ")
        let base = "is:open is:pr archived:false" + (scope.isEmpty ? "" : " " + scope)
        return (base + " author:@me", base + " review-requested:@me")
    }

    static let graphql = """
    query($mine: String!, $review: String!) {
      viewer { login }
      mine: search(query: $mine, type: ISSUE, first: \(PRPolling.resultLimit)) { nodes { ...pr } }
      review: search(query: $review, type: ISSUE, first: \(PRPolling.resultLimit)) { nodes { ...pr } }
    }
    fragment pr on PullRequest {
      number title url isDraft updatedAt headRefName baseRefName additions deletions changedFiles
      mergeable mergeStateStatus reviewDecision
      author { __typename login }
      repository { name nameWithOwner }
      reviewRequests { totalCount }
      latestReviews(first: 10) { nodes { state author { login } } }
      comments(last: 1) { nodes { bodyText author { login } } }
      commits(last: 1) { nodes { commit { statusCheckRollup { state contexts(first: \(PRPolling.checksLimit)) {
        totalCount
        nodes { __typename ... on CheckRun { name status conclusion } ... on StatusContext { context state } }
      } } } } }
    }
    """
}

enum PRText {
    static let title = "Pull Requests"
    static let open = "Abrir"
    static let later = "Depois"
    static let empty = "Nenhuma PR aberta com você."
    static let loading = "Buscando suas PRs…"
    static let missingCLI = "O gh não está instalado. Instale com brew install gh e rode gh auth login."
    static let notLoggedIn = "O gh não está logado. Rode gh auth login no terminal."
    static let failedPrefix = "Não consegui buscar as PRs: "
    static let attentionLabel = "Pull requests pedindo você"
    static let noChecks = "sem checks"
    static let noReview = "sem review ainda"
    static let noConflict = "sem conflito"
    static let conflict = "com conflito"
    static let separator = "·"
    static let arrow = "→"

    static func attention(_ count: Int) -> String {
        count == 0 ? "Nada com você" : "\(count) com você"
    }

    static func number(_ pr: PullRequest) -> String { "\(pr.repository)#\(pr.number)" }
    static func author(_ login: String) -> String { "de \(login)" }
    static func size(_ pr: PullRequest) -> String {
        pr.changedFiles == 1 ? "em 1 arquivo" : "em \(pr.changedFiles) arquivos"
    }
    static func failedCheck(_ name: String, others: Int) -> String {
        others > 0 ? "✕ \(name) e mais \(others) falharam" : "✕ \(name) falhou"
    }
    static func passed(_ passed: Int, of total: Int) -> String {
        passed == total ? "✓ \(total) checks" : "✓ \(passed) de \(total) checks"
    }
    static func running(_ count: Int) -> String {
        count == 1 ? "● 1 check rodando" : "● \(count) checks rodando"
    }
    static func approvals(_ count: Int) -> String {
        count == 1 ? "aprovou" : "\(count) aprovações"
    }
    static func changesBy(_ count: Int) -> String {
        count == 1 ? "pediu mudanças" : "\(count) pediram mudanças"
    }
    static func requestedToYou(others: Int) -> String {
        others > 0 ? "pedido a você e a mais \(others)" : "pedido a você"
    }
    static func requested(_ count: Int) -> String {
        count == 1 ? "review pedido a 1 pessoa" : "review pedido a \(count) pessoas"
    }
    static func comment(_ comment: PRComment) -> String {
        let text = comment.body.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let short = text.count > PRLayout.quoteLength ? String(text.prefix(PRLayout.quoteLength)) + "…" : text
        return "\(comment.author): “\(short)”"
    }

    static func ago(from date: Date, to now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return "agora" }
        if minutes < 60 { return "\(minutes) min" }
        if minutes < 60 * 24 { return "\(minutes / 60) h" }
        return "\(minutes / (60 * 24)) d"
    }
}
