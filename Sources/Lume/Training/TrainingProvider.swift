import Foundation

@MainActor
final class TrainingProvider {
    private let model: NotchModel
    private var timer: Timer?

    init(model: NotchModel) {
        self.model = model
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: TrainingConfig.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        Task {
            let result = await Task.detached { TrainingClient.fetch() }.value
            model.update(TrainingBuilder.category(from: result, now: Date()))
        }
    }
}

enum TrainingClient {
    static func fetch() -> Result<[String: Any], TrainingError> {
        guard let script = Bundle.main.path(forResource: TrainingConfig.scriptName, ofType: "py") else {
            return .failure(.missingScript)
        }
        guard FileManager.default.isExecutableFile(atPath: TrainingConfig.python) else {
            return .failure(.missingPython)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: TrainingConfig.python)
        process.arguments = [script]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(.failed("Resposta inesperada do Garmin"))
        }
        if let message = json["error"] as? String {
            return .failure(.failed(message))
        }
        return .success(json)
    }
}

enum TrainingError: Error {
    case missingScript
    case missingPython
    case failed(String)

    var message: String {
        switch self {
        case .missingScript: return "Script do Garmin não encontrado no app"
        case .missingPython: return "Ambiente do garmin_mcp_server não encontrado"
        case .failed(let detail): return "Garmin: \(detail)"
        }
    }
}

enum TrainingBuilder {
    static func category(from result: Result<[String: Any], TrainingError>, now: Date) -> LumeCategory {
        var category = TrainingConfig.category
        switch result {
        case .failure(let error):
            category.subtitle = "sem dados"
            category.rows = [ContentRow(title: "Não foi possível ler o Garmin", detail: error.message)]
            return category
        case .success(let json):
            category.subtitle = "Garmin · atualizado às \(AgendaBuilder.clock(now))"
            category.tiles = tiles(json)
            category.rows = rows(json)
            category.bars = bars(json, now: now)
            return category
        }
    }

    private static func tiles(_ json: [String: Any]) -> [StatTile] {
        let battery = json["bodyBattery"] as? Int
        let sleep = json["sleepSeconds"] as? Double ?? (json["sleepSeconds"] as? Int).map(Double.init)
        let steps = json["steps"] as? Int
        let score = json["readinessScore"] as? Int
        let level = (json["readinessLevel"] as? String).flatMap { TrainingConfig.readinessLevels[$0] }

        return [
            StatTile(
                label: "Body Battery",
                value: battery.map(String.init) ?? "—",
                trend: battery.map { $0 >= TrainingConfig.goodBodyBattery ? .up : .down } ?? .neutral
            ),
            StatTile(label: "Sono", value: sleep.map { AgendaBuilder.duration($0) } ?? "—"),
            StatTile(label: "Passos", value: steps.map(formatThousands) ?? "—"),
            StatTile(label: "Prontidão", value: [score.map(String.init), level].compactMap { $0 }.joined(separator: " · ").nonEmpty ?? "—")
        ]
    }

    private static func rows(_ json: [String: Any]) -> [ContentRow] {
        guard let workout = json["workout"] as? [String: Any] else {
            return [ContentRow(time: "Hoje", title: "Nenhum treino agendado", detail: "Dia livre no calendário do Garmin")]
        }
        let duration = (workout["durationSeconds"] as? Double ?? (workout["durationSeconds"] as? Int).map(Double.init))
            .map { AgendaBuilder.duration($0) }
        let exercises = workout["exercises"] as? [[String: Any]] ?? []
        let summary = [exercises.isEmpty ? nil : "\(exercises.count) exercícios", duration].compactMap { $0 }.joined(separator: " · ")

        var rows = [ContentRow(time: "Hoje", title: workout["name"] as? String ?? "Treino", detail: summary.nonEmpty)]
        rows += exercises.map { exercise in
            let sets = exercise["sets"] as? Int
            let reps = exercise["reps"] as? Int
            let weight = exercise["weightKg"] as? Double
            let volume = [sets.map(String.init), reps.map(String.init)].compactMap { $0 }.joined(separator: " × ")
            let trailing = [volume.nonEmpty, weight.map { "\(formatWeight($0)) kg" }].compactMap { $0 }.joined(separator: " · ")
            return ContentRow(title: exercise["name"] as? String ?? "Exercício", trailing: trailing.nonEmpty)
        }
        return rows
    }

    private static func bars(_ json: [String: Any], now: Date) -> [WeekBar] {
        let week = json["week"] as? [[String: Any]] ?? []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: now)
        return week.enumerated().map { index, day in
            WeekBar(
                label: TrainingConfig.weekdayLabels[index % TrainingConfig.weekdayLabels.count],
                value: Double(day["minutes"] as? Int ?? 0),
                isToday: day["date"] as? String == today
            )
        }
    }

    private static func formatThousands(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: VoiceConfig.localeID)
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func formatWeight(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
