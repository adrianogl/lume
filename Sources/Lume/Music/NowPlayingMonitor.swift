import AppKit

@MainActor
final class NowPlayingMonitor {
    private let model: NotchModel
    private var observers: [NSObjectProtocol] = []

    init(model: NotchModel) {
        self.model = model
    }

    func start() {
        let center = DistributedNotificationCenter.default()
        for source in MusicConfig.sources {
            let appName = source.appName
            let observer = center.addObserver(forName: Notification.Name(source.notificationName), object: nil, queue: .main) { [weak self] notification in
                let playing = NowPlayingReader.parse(notification.userInfo, appName: appName)
                MainActor.assumeIsolated { self?.update(playing) }
            }
            observers.append(observer)
        }

        Task {
            let playing = await NowPlayingReader.currentSpotifyTrack()
            if model.nowPlaying == nil {
                model.nowPlaying = playing
            }
        }
    }

    private func update(_ playing: NowPlaying?) {
        var next = playing
        if let current = model.nowPlaying, let playing, current.title == playing.title, current.artist == playing.artist {
            next?.artworkURL = current.artworkURL
        }
        model.nowPlaying = next

        guard let next, next.artworkURL == nil, next.appName == MusicConfig.spotify.appName else { return }
        Task {
            let url = await NowPlayingReader.spotifyArtworkURL()
            guard model.nowPlaying?.title == next.title else { return }
            model.nowPlaying?.artworkURL = url
        }
    }

    func send(_ command: MusicCommand) {
        guard let appName = model.nowPlaying?.appName else { return }
        Task.detached {
            _ = AppleScriptRunner.run("tell application \"\(appName)\" to \(command.rawValue)")
        }
    }
}

enum NowPlayingReader {
    static func parse(_ info: [AnyHashable: Any]?, appName: String) -> NowPlaying? {
        guard let info,
              let state = info["Player State"] as? String,
              state == MusicConfig.playingState || state == MusicConfig.pausedState,
              let title = info["Name"] as? String, !title.isEmpty else { return nil }
        let artist = info["Artist"] as? String ?? ""
        return NowPlaying(title: title, artist: artist, isPlaying: state == MusicConfig.playingState, appName: appName)
    }

    static func currentSpotifyTrack() async -> NowPlaying? {
        let isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: MusicConfig.spotify.bundleID).isEmpty
        guard isRunning else { return nil }

        return await Task.detached {
            guard let output = AppleScriptRunner.run(MusicConfig.spotifyCurrentTrackScript) else { return nil }
            let lines = output.components(separatedBy: .newlines)
            guard lines.count >= 3, !lines[0].isEmpty else { return nil }

            let state = lines[2].lowercased()
            guard state == "playing" || state == "paused" else { return nil }
            let artwork = lines.count >= 4 ? URL(string: lines[3]) : nil
            return NowPlaying(title: lines[0], artist: lines[1], isPlaying: state == "playing", appName: MusicConfig.spotify.appName, artworkURL: artwork)
        }.value
    }

    static func spotifyArtworkURL() async -> URL? {
        await Task.detached {
            AppleScriptRunner.run(MusicConfig.spotifyArtworkScript).flatMap { URL(string: $0) }
        }.value
    }
}

enum AppleScriptRunner {
    static func run(_ script: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
