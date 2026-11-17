import Foundation

enum PullRequestClient {
    static func fetch() throws -> (mine: [PullRequest], review: [PullRequest]) {
        guard let gh = PRConfig.ghCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw PRError.ghNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: gh)
        process.arguments = ["api", "graphql", "-f", "query=\(PRConfig.query)"]
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        do {
            try process.run()
        } catch {
            throw PRError.command(error.localizedDescription)
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw PRError.command(detail)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let root = json["data"] as? [String: Any] else { throw PRError.decode }
        return (parse(root["mine"]), parse(root["review"]))
    }

    private static func parse(_ value: Any?) -> [PullRequest] {
        guard let search = value as? [String: Any], let nodes = search["nodes"] as? [[String: Any]] else { return [] }
        return nodes.compactMap(pullRequest)
    }

    private static func pullRequest(_ node: [String: Any]) -> PullRequest? {
        guard let number = node["number"] as? Int,
              let title = node["title"] as? String,
              let urlString = node["url"] as? String, let url = URL(string: urlString),
              let repository = (node["repository"] as? [String: Any])?["name"] as? String else { return nil }

        let reviews = ((node["latestReviews"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? []
        let approvals = reviews.filter { $0["state"] as? String == "APPROVED" }.count
        let decision = node["reviewDecision"] as? String
        let commits = ((node["commits"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? []
        let rollup = ((commits.first?["commit"] as? [String: Any])?["statusCheckRollup"] as? [String: Any])?["state"] as? String
        let comments = ((node["comments"] as? [String: Any])?["totalCount"] as? Int ?? 0)
            + ((node["reviewThreads"] as? [String: Any])?["totalCount"] as? Int ?? 0)

        return PullRequest(
            id: urlString,
            number: number,
            title: title,
            url: url,
            repository: repository,
            author: ((node["author"] as? [String: Any])?["login"] as? String) ?? "",
            updatedAt: (node["updatedAt"] as? String).flatMap(DateParsing.iso) ?? .distantPast,
            isDraft: node["isDraft"] as? Bool ?? false,
            ci: ciState(rollup),
            hasConflict: node["mergeable"] as? String == "CONFLICTING",
            changesRequested: decision == "CHANGES_REQUESTED",
            approvals: approvals,
            isApproved: decision == "APPROVED" || (decision == nil && approvals > 0),
            comments: comments
        )
    }

    private static func ciState(_ rollup: String?) -> CIState {
        switch rollup {
        case "SUCCESS": return .pass
        case "FAILURE", "ERROR": return .fail
        case "PENDING", "EXPECTED": return .running
        default: return .none
        }
    }
}
