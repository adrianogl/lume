import Foundation

enum PullRequestAlerts {
    static func changes(oldMine: [PullRequest], newMine: [PullRequest], oldReview: [PullRequest], newReview: [PullRequest]) -> [NotchAlert] {
        var alerts: [NotchAlert] = []
        let previous = Dictionary(uniqueKeysWithValues: oldMine.map { ($0.id, $0) })

        for pr in newMine {
            guard let old = previous[pr.id] else { continue }
            if old.ci != .fail && pr.ci == .fail {
                alerts.append(alert(.failure, "CI falhou", pr))
            } else if old.ci != .pass && pr.ci == .pass {
                alerts.append(alert(.success, "CI passou", pr))
            }
            if !old.isApproved && pr.isApproved {
                alerts.append(alert(.success, "PR aprovado", pr))
            }
            if !old.changesRequested && pr.changesRequested {
                alerts.append(alert(.failure, "Alterações pedidas", pr))
            }
            if pr.comments > old.comments {
                alerts.append(alert(.info, "Comentário novo", pr))
            }
        }

        let knownReviews = Set(oldReview.map(\.id))
        for pr in newReview where !knownReviews.contains(pr.id) {
            let author = pr.author.isEmpty ? "" : " · por \(pr.author)"
            alerts.append(NotchAlert(
                kind: .info,
                title: "Review pedido a você",
                subtitle: "\(pr.repository) #\(pr.number)\(author) · \(pr.title)",
                actionTitle: "Revisar",
                actionURL: pr.url
            ))
        }

        return Array(alerts.prefix(AlertConfig.maxPerRefresh))
    }

    private static func alert(_ kind: NotchAlert.Kind, _ title: String, _ pr: PullRequest) -> NotchAlert {
        NotchAlert(
            kind: kind,
            title: title,
            subtitle: "\(pr.repository) #\(pr.number) · \(pr.title)",
            actionTitle: "Abrir PR",
            actionURL: pr.url
        )
    }
}
