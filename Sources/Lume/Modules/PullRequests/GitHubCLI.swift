import Foundation

enum GitHubCLIError: Error {
    case missing
    case notLoggedIn
    case failed(String)
}

struct GitHubSnapshot: Sendable {
    let login: String
    let pullRequests: [PullRequest]
}

enum GitHubCLI {
    static func executable() -> String? {
        let fromPath = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map { "\($0)/gh" }
        return (PRPolling.ghCandidates + fromPath).first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func fetch(organizations: [String]) throws -> GitHubSnapshot {
        guard let gh = executable() else { throw GitHubCLIError.missing }
        let searches = PRQuery.searches(organizations: organizations)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gh)
        process.arguments = [
            "api", "graphql",
            "-f", "query=\(PRQuery.graphql)",
            "-f", "mine=\(searches.mine)",
            "-f", "review=\(searches.review)"
        ]
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if message.contains(PRPolling.authHint) { throw GitHubCLIError.notLoggedIn }
            throw GitHubCLIError.failed(message.isEmpty ? "gh saiu com código \(process.terminationStatus)" : message)
        }
        return try parse(data)
    }

    static func parse(_ data: Data) throws -> GitHubSnapshot {
        let response = try JSONDecoder().decode(GraphResponse.self, from: data)
        let login = response.data.viewer.login
        var seen = Set<String>()
        let nodes = (response.data.mine.nodes + response.data.review.nodes).compactMap { $0 }
        let pullRequests = nodes.compactMap { node -> PullRequest? in
            guard let url = URL(string: node.url), seen.insert(node.url).inserted else { return nil }
            return node.pullRequest(url: url, viewer: login)
        }
        return GitHubSnapshot(login: login, pullRequests: pullRequests)
    }
}

private struct GraphResponse: Decodable {
    struct Payload: Decodable {
        let viewer: Viewer
        let mine: Search
        let review: Search
    }
    struct Viewer: Decodable { let login: String }
    struct Search: Decodable { let nodes: [Node?] }
    let data: Payload
}

private struct Node: Decodable {
    struct Actor: Decodable {
        let login: String
        let __typename: String?
    }
    struct Repository: Decodable { let name: String }
    struct Count: Decodable { let totalCount: Int }
    struct Review: Decodable {
        let state: String
        let author: Actor?
    }
    struct Reviews: Decodable { let nodes: [Review?] }
    struct Comment: Decodable {
        let bodyText: String
        let author: Actor?
    }
    struct Comments: Decodable { let nodes: [Comment?] }
    struct Context: Decodable {
        let __typename: String
        let name: String?
        let status: String?
        let conclusion: String?
        let context: String?
        let state: String?
    }
    struct Contexts: Decodable { let nodes: [Context?] }
    struct Rollup: Decodable { let contexts: Contexts }
    struct Commit: Decodable { let statusCheckRollup: Rollup? }
    struct CommitNode: Decodable { let commit: Commit }
    struct Commits: Decodable { let nodes: [CommitNode?] }

    let number: Int
    let title: String
    let url: String
    let isDraft: Bool
    let updatedAt: String
    let headRefName: String
    let baseRefName: String
    let additions: Int
    let deletions: Int
    let changedFiles: Int
    let mergeable: String
    let mergeStateStatus: String
    let reviewDecision: String?
    let author: Actor?
    let repository: Repository
    let reviewRequests: Count
    let latestReviews: Reviews
    let comments: Comments
    let commits: Commits

    private static let failedConclusions: Set = ["FAILURE", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE"]
    private static let failedStates: Set = ["FAILURE", "ERROR"]
    private static let runningStates: Set = ["PENDING", "EXPECTED"]

    func pullRequest(url: URL, viewer: String) -> PullRequest {
        let reviews = latestReviews.nodes.compactMap { $0 }
        let comment = comments.nodes.compactMap { $0 }.last { !$0.bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return PullRequest(
            url: url,
            number: number,
            title: title,
            repository: repository.name,
            author: author?.login ?? "",
            isMine: author?.login == viewer,
            isDraft: isDraft,
            isBot: author?.__typename == "Bot",
            headBranch: headRefName,
            baseBranch: baseRefName,
            additions: additions,
            deletions: deletions,
            changedFiles: changedFiles,
            hasConflict: mergeable == "CONFLICTING",
            isClean: mergeStateStatus == "CLEAN",
            reviewDecision: reviewDecision ?? "",
            approvedBy: reviews.filter { $0.state == "APPROVED" }.compactMap { $0.author?.login },
            changesBy: reviews.filter { $0.state == "CHANGES_REQUESTED" }.compactMap { $0.author?.login },
            pendingReviewers: reviewRequests.totalCount,
            checks: checks,
            lastComment: comment.map { PRComment(author: $0.author?.login ?? "", body: $0.bodyText.trimmingCharacters(in: .whitespacesAndNewlines)) },
            updatedAt: ISO8601DateFormatter().date(from: updatedAt) ?? Date()
        )
    }

    private var checks: PRChecks {
        let contexts = commits.nodes.compactMap { $0 }.last?.commit.statusCheckRollup?.contexts.nodes.compactMap { $0 } ?? []
        var result = PRChecks(total: contexts.count)
        for context in contexts {
            if context.__typename == "CheckRun" {
                if context.status != "COMPLETED" {
                    result.running += 1
                } else if Self.failedConclusions.contains(context.conclusion ?? "") {
                    result.failedNames.append(context.name ?? "")
                } else {
                    result.passed += 1
                }
            } else if Self.runningStates.contains(context.state ?? "") {
                result.running += 1
            } else if Self.failedStates.contains(context.state ?? "") {
                result.failedNames.append(context.context ?? "")
            } else {
                result.passed += 1
            }
        }
        return result
    }
}
