import CryptoKit
import Foundation

struct Account: Identifiable, Hashable {
    let name: String
    let configDir: URL

    var id: String { name }

    var projectsDir: URL { configDir.appendingPathComponent("projects") }

    var keychainService: String {
        let defaultDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path
        if configDir.path == defaultDir { return UsageConfig.keychainService }
        let digest = SHA256.hash(data: Data(configDir.path.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return UsageConfig.keychainService + "-" + hex.prefix(8)
    }
}

struct LimitWindow: Equatable, Codable {
    let utilization: Double
    let resetsAt: Date?
}

struct LimitSnapshot: Equatable, Codable {
    let fiveHour: LimitWindow?
    let sevenDay: LimitWindow?
    let plan: String?
    let fetchedAt: Date
}

enum UsageError: Error {
    case noCredentials
    case expired
    case http(Int)
    case rateLimited(retryAfter: TimeInterval?)
    case decode

    var message: String {
        switch self {
        case .noCredentials: return "Sem login nesta conta"
        case .expired: return "Token expirado: abra o Claude Code nesta conta"
        case .http(let code): return "Erro \(code) ao buscar limites"
        case .rateLimited: return "API limitou as consultas"
        case .decode: return "Resposta inesperada da API"
        }
    }
}

struct AccountState {
    var snapshot: LimitSnapshot?
    var error: String?
    var daily: [Date: Int] = [:]
    var hourlyToday: [Int: Int] = [:]
    var logsLoaded = false
}

enum Period: String, CaseIterable, Identifiable {
    case days30, days15, week, today

    var id: String { rawValue }

    var label: String {
        switch self {
        case .days30: return "30 dias"
        case .days15: return "15 dias"
        case .week: return "1 semana"
        case .today: return "Hoje"
        }
    }

    var dayCount: Int {
        switch self {
        case .days30: return 30
        case .days15: return 15
        case .week: return 7
        case .today: return 1
        }
    }
}

struct TokenEntry {
    let key: String
    let date: Date
    let tokens: Int
}

struct ChartPoint: Identifiable {
    let account: String
    let x: Date
    let tokens: Int
    var id: String { account + "|" + String(x.timeIntervalSince1970) }
}

struct WeeklyForecast {
    enum Outcome {
        case atLimit
        case hits(Date)
        case closes(Double)
    }

    let usedPercent: Double
    let projectedPercent: Double
    let ratePerDay: Double
    let resetsAt: Date
    let outcome: Outcome
}
