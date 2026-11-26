import SwiftUI

enum MusicApp: String, CaseIterable {
    case spotify, music

    var bundleID: String {
        switch self {
        case .spotify: "com.spotify.client"
        case .music: "com.apple.Music"
        }
    }

    var scriptName: String {
        switch self {
        case .spotify: "Spotify"
        case .music: "Music"
        }
    }

    var displayName: String {
        switch self {
        case .spotify: "Spotify"
        case .music: "Música"
        }
    }

    var notification: Notification.Name {
        switch self {
        case .spotify: Notification.Name("com.spotify.client.PlaybackStateChanged")
        case .music: Notification.Name("com.apple.Music.playerInfo")
        }
    }

    var color: Color {
        switch self {
        case .spotify: Color(red: 30 / 255, green: 215 / 255, blue: 96 / 255)
        case .music: Color(red: 250 / 255, green: 45 / 255, blue: 72 / 255)
        }
    }

    var durationIsMilliseconds: Bool { self == .spotify }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}

struct NowPlaying: Equatable {
    let app: MusicApp
    let title: String
    let artist: String
    let isPlaying: Bool
    let duration: TimeInterval?
    let position: TimeInterval
    let fetchedAt: Date
    var artwork: NSImage?

    func position(at date: Date) -> TimeInterval {
        let elapsed = isPlaying ? date.timeIntervalSince(fetchedAt) : 0
        let current = position + elapsed
        guard let duration else { return current }
        return min(current, duration)
    }

    func isSameTrack(as other: NowPlaying?) -> Bool {
        guard let other else { return false }
        return other.app == app && other.title == title && other.artist == artist
    }

    static func == (lhs: NowPlaying, rhs: NowPlaying) -> Bool {
        lhs.app == rhs.app && lhs.title == rhs.title && lhs.artist == rhs.artist
            && lhs.isPlaying == rhs.isPlaying && lhs.duration == rhs.duration
            && lhs.position == rhs.position && lhs.artwork === rhs.artwork
    }
}

enum MusicCommand: String {
    case playPause = "playpause"
    case next = "next track"
    case previous = "previous track"
}
