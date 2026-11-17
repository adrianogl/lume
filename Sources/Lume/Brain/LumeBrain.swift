import Foundation
import FoundationModels

@available(macOS 26.0, *)
@Generable
struct BrainAnswer {
    @Guide(description: "Resposta curta em português do Brasil, em no máximo duas frases, para ser falada em voz alta.")
    let reply: String

    @Guide(description: "Categoria do Lume que mostra os detalhes da resposta.", .anyOf(["agenda", "prs", "treino", "claude", "nenhuma"]))
    let category: String
}

@MainActor
final class LumeBrain {
    private let model: NotchModel
    private let prs: PullRequestStore
    private let usage: UsageStore

    init(model: NotchModel, prs: PullRequestStore, usage: UsageStore) {
        self.model = model
        self.prs = prs
        self.usage = usage
    }

    func answer(_ question: String) async -> BrainReply {
        guard #available(macOS 26.0, *) else { return BrainReply(text: BrainConfig.unavailableReply) }
        guard case .available = SystemLanguageModel.default.availability else {
            return BrainReply(text: BrainConfig.unavailableReply)
        }

        let context = BrainContext.build(model: model, prs: prs, usage: usage, now: Date())
        let session = LanguageModelSession(instructions: BrainConfig.instructions)
        let prompt = "Contexto atual:\n\(context)\n\nPergunta do usuário: \(question)"
        do {
            let response = try await session.respond(to: prompt, generating: BrainAnswer.self)
            let category = response.content.category
            return BrainReply(
                text: response.content.reply,
                categoryID: BrainConfig.categoryIDs.contains(category) && category != "nenhuma" ? category : nil
            )
        } catch {
            return BrainReply(text: BrainConfig.failureReply)
        }
    }
}

@MainActor
enum BrainContext {
    static func build(model: NotchModel, prs: PullRequestStore, usage: UsageStore, now: Date) -> String {
        var sections: [String] = []

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: VoiceConfig.localeID)
        formatter.dateFormat = "EEEE, dd/MM/yyyy, HH:mm"
        sections.append("Agora: \(formatter.string(from: now)).")

        if let agenda = model.categories.first(where: { $0.id == AgendaConfig.categoryID }) {
            sections.append(describe(agenda, heading: "Agenda de hoje"))
        }

        if prs.lastRefresh != nil {
            sections.append(pullRequests("PRs abertos do usuário", prs.mine))
            sections.append(pullRequests("PRs do usuário prontos para merge", prs.ready))
            sections.append(pullRequests("Reviews pedidos ao usuário", prs.review))
        }

        if let training = model.categories.first(where: { $0.id == TrainingConfig.categoryID }) {
            sections.append(describe(training, heading: "Treino e saúde (Garmin)"))
        }

        let limits = usage.accounts.compactMap { account -> String? in
            guard let snapshot = usage.states[account.name]?.snapshot else { return nil }
            let fiveHour = snapshot.fiveHour.map { "\(Int($0.utilization))%" } ?? "sem dado"
            let weekly = snapshot.sevenDay.map { "\(Int($0.utilization))%" } ?? "sem dado"
            return "- conta \(account.name): janela de 5h em \(fiveHour), semana em \(weekly)"
        }
        if !limits.isEmpty {
            sections.append("Uso do Claude:\n" + limits.joined(separator: "\n"))
        }

        return sections.joined(separator: "\n\n")
    }

    private static func describe(_ category: LumeCategory, heading: String) -> String {
        var lines = ["\(heading):"]
        lines += category.tiles.map { "- \($0.label): \($0.value)" }
        lines += category.rows.prefix(BrainConfig.maxItemsPerList).map { row in
            [row.time, row.title, row.detail, row.trailing].compactMap { $0 }.joined(separator: " · ")
        }.map { "- \($0)" }
        return lines.joined(separator: "\n")
    }

    private static func pullRequests(_ heading: String, _ items: [PullRequest]) -> String {
        guard !items.isEmpty else { return "\(heading): nenhum." }
        let lines = items.prefix(BrainConfig.maxItemsPerList).map { pr in
            var facts: [String] = []
            switch pr.ci {
            case .pass: facts.append("CI passou")
            case .fail: facts.append("CI falhou")
            case .running: facts.append("CI rodando")
            case .none: break
            }
            if pr.isApproved { facts.append("aprovado") }
            if pr.changesRequested { facts.append("alterações pedidas") }
            if pr.hasConflict { facts.append("com conflito") }
            if pr.isDraft { facts.append("rascunho") }
            if pr.comments > 0 { facts.append("\(pr.comments) comentários") }
            return "- \(pr.repository) #\(pr.number) \"\(pr.title)\" (\(facts.joined(separator: ", ")))"
        }
        return "\(heading) (\(items.count)):\n" + lines.joined(separator: "\n")
    }
}
