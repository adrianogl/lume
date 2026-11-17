import SwiftUI

enum Palette {
    static let attention = Color(red: 1, green: 170 / 255, blue: 150 / 255)
    static let red = Color(red: 232 / 255, green: 69 / 255, blue: 44 / 255)
    static let redLight = Color(red: 1, green: 106 / 255, blue: 77 / 255)
    static let live = Color(red: 46 / 255, green: 230 / 255, blue: 107 / 255)
    static let panelTint = Color(red: 20 / 255, green: 16 / 255, blue: 20 / 255)
    static let rowFill = Color(red: 38 / 255, green: 33 / 255, blue: 37 / 255)
    static let rowFillHover = Color(red: 50 / 255, green: 44 / 255, blue: 48 / 255)
    static let textMuted = Color.white.opacity(0.55)
    static let up = Color(red: 110 / 255, green: 224 / 255, blue: 166 / 255)
    static let down = Color(red: 1, green: 143 / 255, blue: 128 / 255)

    static func color(for trend: Trend) -> Color {
        switch trend {
        case .up: up
        case .down: down
        case .neutral: .white
        }
    }
}

enum Metrics {
    static let earWidth: CGFloat = 270
    static let earPadding: CGFloat = 20
    static let openEarPadding: CGFloat = 32
    static let openContentPadding: CGFloat = 30
    static let openSize = CGSize(width: 960, height: 580)
    static let openCornerRadius: CGFloat = 28
    static let closedCornerRadius: CGFloat = 14
    static let closedTopFlare: CGFloat = 6
    static let openTopFlare: CGFloat = 14
    static let sidebarWidth: CGFloat = 190
    static let windowSize = CGSize(width: 1060, height: 640)
    static let glowDiameter: CGFloat = 820
    static let hoverOpenDelay: Double = 0.12
    static let hoverCloseDelay: Double = 0.5
    static let fallbackNotchWidth: CGFloat = 300
    static let fallbackNotchMinHeight: CGFloat = 32
}

enum LaunchOptions {
    static let startOpenKey = "LUME_START_OPEN"
    static let demoAlertKey = "LUME_DEMO_ALERT"
}

enum MusicConfig {
    static let spotify = MusicSource(appName: "Spotify", bundleID: "com.spotify.client", notificationName: "com.spotify.client.PlaybackStateChanged")
    static let appleMusic = MusicSource(appName: "Music", bundleID: "com.apple.Music", notificationName: "com.apple.Music.playerInfo")
    static let sources = [spotify, appleMusic]
    static let playingState = "Playing"
    static let pausedState = "Paused"
    static let spotifyCurrentTrackScript = """
    tell application "Spotify"
        set t to current track
        return (name of t) & linefeed & (artist of t) & linefeed & (player state as text) & linefeed & (artwork url of t)
    end tell
    """
    static let spotifyArtworkScript = "tell application \"Spotify\" to artwork url of current track"
}

enum VoiceConfig {
    static let localeID = "pt-BR"
    static let idleLevels: [Double] = [0.27, 0.64, 1, 0.55, 0.27]
    static let idleBreathPeriod: Double = 3.6
    static let idleBreathStagger: Double = 0.45
    static let idleMinScale: CGFloat = 0.55
    static let wakeWords = ["lume", "lumi", "lumen"]
    static let commandSilence: Double = 1.5
    static let commandStartTimeout: Double = 5
    static let wakeRestartInterval: Double = 50
    static let failureRestartDelay: Double = 1
    static let processingDelay: Double = 0.8
    static let wakeSoundName = "Tink"
    static let placeholderReply = "Ainda não sei responder. O cérebro entra no próximo passo."
}

enum AgendaConfig {
    static let categoryID = "agenda"
    static let workdayStartHour = 8
    static let workdayEndHour = 19
    static let maxRows = 6
    static let refreshInterval: Double = 30
    static let joinCheckInterval: Double = 5
    static let micIgnoredBundleFragments = ["wispr", "speech", "siri", "dictation", "local.lume.app"]
    static let timeFormat = "HH:mm"
    static let joinWindow: TimeInterval = 600
    static let meetingAlertWindow: TimeInterval = 300
    static let meetingLinkPattern = #"https://(?:teams\.microsoft\.com/l/meetup-join|teams\.live\.com/meet|meet\.google\.com|[\w.-]*zoom\.us/(?:j|my|w))[^\s<>"')\]]*"#

    static let placeholder = LumeCategory(
        id: categoryID, name: "Agenda", symbol: "calendar",
        earText: "Carregando agenda",
        title: "Hoje", subtitle: "",
        rows: [ContentRow(title: "Carregando agenda…")]
    )

    static let noAccess = LumeCategory(
        id: categoryID, name: "Agenda", symbol: "calendar",
        earText: "Agenda sem acesso",
        title: "Hoje", subtitle: "",
        rows: [ContentRow(title: "Sem acesso ao Calendário", detail: "Libere em Ajustes do Sistema › Privacidade e Segurança › Calendários")]
    )
}

enum UsageConfig {
    static let categoryID = "claude"
    static let category = LumeCategory(
        id: categoryID, name: "Claude", symbol: "gauge.with.dots.needle.67percent",
        earText: "", title: "Uso do Claude", subtitle: ""
    )
    static let accounts: [Account] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [("Pessoal", ".claude"), ("EMS", ".claude-ems"), ("Thaís", ".claude-thais")].map {
            Account(name: $0.0, configDir: home.appendingPathComponent($0.1))
        }
    }()
    static let accountColors: [Color] = [
        Color(red: 1, green: 106 / 255, blue: 77 / 255),
        Color.white.opacity(0.9),
        Color(red: 170 / 255, green: 160 / 255, blue: 175 / 255)
    ]
    static let allAccountsLabel = "Todas"
    static let automaticAccount = "auto"
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let oauthBeta = "oauth-2025-04-20"
    static let keychainService = "Claude Code-credentials"
    static let limitsInterval: TimeInterval = 300
    static let logsInterval: TimeInterval = 60
    static let minFetchInterval: TimeInterval = 240
    static let rateLimitFallback: TimeInterval = 900
    static let defaultAlertThreshold: Double = 80
    static let warningLevel: Double = 60
    static let criticalLevel: Double = 85
    static let scanDays = 31
    static let weeksAtLimitWindow: TimeInterval = 35 * 86_400
    static let weekLength: TimeInterval = 7 * 86_400
    static let forecastMinElapsedDays = 0.25
    static let legacyDefaultsSuite = "local.claude-usage-bar"

    enum Keys {
        static let menuAccount = "menuAccount"
        static let alertThreshold = "alertThreshold"
        static let weeklyPeaks = "weeklyPeaks"
        static let notified = "notifiedWindows"
        static let snapshots = "snapshots"
        static let excludeWeekends = "excludeWeekends"
        static let migrated = "usageMigratedFromLegacy"
        static let all = [menuAccount, alertThreshold, weeklyPeaks, notified, snapshots, excludeWeekends]
    }
}

enum PRConfig {
    static let categoryID = "prs"
    static let category = LumeCategory(
        id: categoryID, name: "PRs", symbol: "arrow.triangle.branch",
        earText: "", title: "PRs", subtitle: ""
    )
    static let ghCandidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
    static let refreshInterval: TimeInterval = 120
    static let query = """
    query {
      mine: search(query: "is:pr is:open author:@me archived:false sort:updated-desc", type: ISSUE, first: 30) { nodes { ...pr } }
      review: search(query: "is:pr is:open review-requested:@me archived:false sort:updated-desc", type: ISSUE, first: 30) { nodes { ...pr } }
    }
    fragment pr on PullRequest {
      number title url isDraft updatedAt mergeable reviewDecision
      author { login }
      repository { name nameWithOwner }
      comments { totalCount }
      reviewThreads { totalCount }
      latestReviews(first: 20) { nodes { state } }
      commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
    }
    """
}

enum ClaudeHookConfig {
    static let command = "notify"
    static let notificationName = Notification.Name("local.lume.claude-hook")
    static let kindKey = "kind"
    static let titleKey = "title"
    static let messageKey = "message"
    static let bundleKey = "bundle"
    static let attentionKind = "attention"
    static let actionTitle = "Abrir"
}

enum AlertConfig {
    static let duration: Double = 4
    static let gap: Double = 0.6
    static let height: CGFloat = 46
    static let extraWidth: CGFloat = 40
    static let cornerRadius: CGFloat = 22
    static let maxPerRefresh = 3
}

enum TrainingConfig {
    static let categoryID = "treino"
    static let category = LumeCategory(
        id: categoryID, name: "Treino", symbol: "figure.run",
        earText: "", title: "Treino", subtitle: "carregando…",
        rows: [ContentRow(title: "Lendo dados do Garmin…")]
    )
    static let python = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Code/pessoal/terceiros/garmin_mcp_server/venv/bin/python").path
    static let scriptName = "garmin_today"
    static let refreshInterval: TimeInterval = 900
    static let readinessLevels = ["POOR": "ruim", "LOW": "baixa", "MODERATE": "moderada", "HIGH": "alta", "PRIME": "ótima"]
    static let weekdayLabels = ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"]
    static let goodBodyBattery = 50
}

enum BrainConfig {
    static let instructions = """
    Você é o Lume, assistente pessoal que fica no notch do Mac do usuário.
    Responda sempre em português do Brasil, em no máximo duas frases curtas, porque a resposta é falada em voz alta.
    Use apenas as informações do contexto. Se a resposta não estiver no contexto, diga que ainda não tem essa informação.
    Não invente números, nomes nem horários.
    """
    static let categoryIDs = ["agenda", "prs", "treino", "claude", "nenhuma"]
    static let unavailableReply = "Para eu responder, ative o Apple Intelligence nos Ajustes do Sistema."
    static let failureReply = "Não consegui responder agora. Tente de novo em instantes."
    static let maxItemsPerList = 8
    static let speechRate: Float = 0.52
}

enum AlertHistoryConfig {
    static let bellReservedHeight: CGFloat = 46
    static let maxItems = 40
    static let panelWidth: CGFloat = 380
    static let panelMaxHeight: CGFloat = 320
}
