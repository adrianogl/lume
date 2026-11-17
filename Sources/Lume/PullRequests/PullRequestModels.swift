import Foundation

enum CIState {
    case pass, fail, running, none
}

enum PRTab: CaseIterable {
    case mine, review, ready
}

struct PullRequest: Identifiable {
    let id: String
    let number: Int
    let title: String
    let url: URL
    let repository: String
    let author: String
    let updatedAt: Date
    let isDraft: Bool
    let ci: CIState
    let hasConflict: Bool
    let changesRequested: Bool
    let approvals: Int
    let isApproved: Bool
    let comments: Int

    var isReadyToMerge: Bool {
        !isDraft && isApproved && !changesRequested && !hasConflict && (ci == .pass || ci == .none)
    }
}

enum PRError: Error {
    case ghNotFound
    case command(String)
    case decode

    var message: String {
        switch self {
        case .ghNotFound: return "GitHub CLI não encontrado. Instale com brew install gh e rode gh auth login."
        case .command(let detail): return detail.isEmpty ? "Não foi possível consultar o GitHub" : detail
        case .decode: return "Resposta inesperada do GitHub"
        }
    }
}
