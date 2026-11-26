import Foundation

@MainActor
final class ConfigStore: ObservableObject {
    @Published private(set) var config = LumeConfig()
    @Published private(set) var loadError: String?
    private var watcher: DispatchSourceFileSystemObject?

    private var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(ConfigFile.directory)
    }

    private var fileURL: URL {
        directory.appendingPathComponent(ConfigFile.name)
    }

    func start() {
        createDefaultIfMissing()
        load()
        watch()
    }

    func update(_ change: (inout LumeConfig) -> Void) {
        var updated = config
        change(&updated)
        guard updated != config else { return }
        config = updated
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Self.encoder.encode(updated).write(to: fileURL, options: .atomic)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func createDefaultIfMissing() {
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Self.encoder.encode(LumeConfig()).write(to: fileURL, options: .atomic)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(LumeConfig.self, from: data)
            loadError = nil
            if decoded != config { config = decoded }
        } catch {
            loadError = error.localizedDescription
            NSLog("Lume: config inválida em %@: %@", fileURL.path, error.localizedDescription)
        }
    }

    private func watch() {
        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.load() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        watcher = source
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()
}
