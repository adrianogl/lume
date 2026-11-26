import AppKit

@MainActor
final class MusicController: ObservableObject {
    @Published private(set) var nowPlaying: NowPlaying?
    @Published private(set) var isActive = false

    private let scripts = DispatchQueue(label: "local.lume.music-scripts")
    private var observers: [NSObjectProtocol] = []
    private var isRunning = false
    private var pauseTask: Task<Void, Never>?
    private var showWhilePlaying = true

    func apply(_ config: MusicModuleConfig) {
        showWhilePlaying = config.showWhilePlaying
        if config.enabled, !isRunning {
            start()
        } else if !config.enabled, isRunning {
            stop()
        }
        updateActive()
    }

    func send(_ command: MusicCommand) {
        guard let app = nowPlaying?.app else { return }
        let source = "tell application \"\(app.scriptName)\" to \(command.rawValue)"
        scripts.async { [weak self] in
            _ = MusicScript.run(source)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(MusicLayout.refreshAfterCommand))
                self?.refresh(app)
            }
        }
    }

    private func start() {
        isRunning = true
        let center = DistributedNotificationCenter.default()
        for app in MusicApp.allCases {
            let observer = center.addObserver(forName: app.notification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh(app) }
            }
            observers.append(observer)
            if app.isRunning { refresh(app) }
        }
    }

    private func stop() {
        isRunning = false
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        observers = []
        pauseTask?.cancel()
        nowPlaying = nil
    }

    private func refresh(_ app: MusicApp) {
        guard app.isRunning else {
            if nowPlaying?.app == app { setNowPlaying(nil) }
            return
        }
        scripts.async { [weak self] in
            let info = MusicScript.run(MusicScript.trackInfo(for: app))
            let artworkData = app == .music ? MusicScript.runData(MusicScript.musicArtwork) : nil
            let lines = info?.components(separatedBy: "\n") ?? []
            Task { @MainActor in
                self?.handle(app: app, lines: lines, artworkData: artworkData)
            }
        }
    }

    private func handle(app: MusicApp, lines: [String], artworkData: Data?) {
        guard lines.count >= 5, !lines[0].isEmpty else {
            if nowPlaying?.app == app { setNowPlaying(nil) }
            return
        }
        let rawDuration = MusicScript.number(lines[3])
        let duration = rawDuration.map { app.durationIsMilliseconds ? $0 / 1000 : $0 }
        var playing = NowPlaying(
            app: app,
            title: lines[0],
            artist: lines[1],
            isPlaying: lines[2] == "playing",
            duration: duration,
            position: MusicScript.number(lines[4]) ?? 0,
            fetchedAt: Date()
        )
        if let current = nowPlaying, playing.isSameTrack(as: current) {
            playing.artwork = current.artwork
        }
        if let current = nowPlaying, current.isPlaying, current.app != app, !playing.isPlaying {
            return
        }
        setNowPlaying(playing)

        if playing.artwork == nil {
            if let artworkData, let image = NSImage(data: artworkData) {
                setArtwork(image, for: playing)
            } else if app == .spotify, lines.count >= 6, let url = URL(string: lines[5]) {
                Task { [weak self] in
                    guard let (data, _) = try? await URLSession.shared.data(from: url), let image = NSImage(data: data) else { return }
                    self?.setArtwork(image, for: playing)
                }
            }
        }
    }

    private func setArtwork(_ image: NSImage, for track: NowPlaying) {
        guard var current = nowPlaying, current.isSameTrack(as: track) else { return }
        current.artwork = image
        nowPlaying = current
    }

    private func setNowPlaying(_ playing: NowPlaying?) {
        if let playing {
            nowPlaying = playing
        } else if nowPlaying?.isPlaying == true {
            nowPlaying = nil
        }
        updateActive()
    }

    private func updateActive() {
        pauseTask?.cancel()
        let playing = showWhilePlaying && nowPlaying?.isPlaying == true
        if playing {
            isActive = true
        } else if isActive {
            pauseTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(MusicLayout.pauseGrace))
                guard !Task.isCancelled else { return }
                self?.isActive = false
            }
        }
    }
}

enum MusicScript {
    static let musicArtwork = "tell application \"Music\" to get raw data of artwork 1 of current track"

    static func trackInfo(for app: MusicApp) -> String {
        let artwork = app == .spotify ? " & linefeed & (artwork url of t)" : ""
        return """
        tell application "\(app.scriptName)"
            set t to current track
            return (name of t) & linefeed & (artist of t) & linefeed & (player state as text) & linefeed & (duration of t) & linefeed & (player position)\(artwork)
        end tell
        """
    }

    static func run(_ source: String) -> String? {
        var error: NSDictionary?
        return NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue
    }

    static func runData(_ source: String) -> Data? {
        var error: NSDictionary?
        let data = NSAppleScript(source: source)?.executeAndReturnError(&error).data
        return data?.isEmpty == false ? data : nil
    }

    static func number(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }
}
