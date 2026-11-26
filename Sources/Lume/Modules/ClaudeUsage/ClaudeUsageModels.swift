import SwiftUI

enum UsageWindowKind: String, Codable {
    case fiveHour, sevenDay
}

struct UsageWindow: Codable, Equatable {
    let usedPercentage: Int
    let resetsAt: Date

    func used(at now: Date) -> Int {
        resetsAt <= now ? 0 : usedPercentage
    }
}

struct UsageSnapshot: Codable, Equatable {
    let account: String
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let updatedAt: Date

    func window(_ kind: UsageWindowKind) -> UsageWindow? {
        kind == .fiveHour ? fiveHour : sevenDay
    }
}

struct UsageEntry: Identifiable, Equatable {
    let name: String
    let snapshot: UsageSnapshot

    var id: String { snapshot.account }

    func isActive(at now: Date) -> Bool {
        now.timeIntervalSince(snapshot.updatedAt) < UsageLayout.activeWindow
    }

    func isStale(at now: Date) -> Bool {
        now.timeIntervalSince(snapshot.updatedAt) > UsageLayout.staleAfter
    }

    func peak(at now: Date) -> Int {
        max(snapshot.fiveHour?.used(at: now) ?? 0, snapshot.sevenDay?.used(at: now) ?? 0)
    }
}

struct UsageAlert: Identifiable, Equatable {
    let id = UUID()
    let account: String
    let window: UsageWindowKind
    let threshold: Int
    let resetsAt: Date

    var isHot: Bool { threshold >= UsageLayout.hotLimit }
    var color: Color { isHot ? NotchRim.coral : NotchRim.amber }
}

enum UsageStore {
    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(ConfigFile.directory)
            .appendingPathComponent(UsageStatusLine.folder)
    }

    static func file(for account: String) -> URL {
        directory.appendingPathComponent(URL(fileURLWithPath: account).lastPathComponent + ".json")
    }

    static func save(_ snapshot: UsageSnapshot) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        try encoder.encode(snapshot).write(to: file(for: snapshot.account), options: .atomic)
    }

    static func loadAll() -> [UsageSnapshot] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(UsageSnapshot.self, from: Data(contentsOf: $0)) }
    }
}
