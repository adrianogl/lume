import Foundation

enum CommandShellInstaller {
    private static var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    static var rcFile: URL { home.appendingPathComponent(CommandShell.rcFile).resolvingSymlinksInPath() }
    static var scriptFile: URL {
        home.appendingPathComponent(CommandShell.scriptDirectory).appendingPathComponent(CommandShell.scriptName)
    }

    static func isInstalled() -> Bool {
        guard let rc = try? String(contentsOf: rcFile, encoding: .utf8) else { return false }
        return rc.contains(CommandShell.marker) && FileManager.default.fileExists(atPath: scriptFile.path)
    }

    static func install(executable: String) throws {
        try writeScript(executable: executable)
        let rc = (try? String(contentsOf: rcFile, encoding: .utf8)) ?? ""
        guard !rc.contains(CommandShell.marker) else { return }
        try backupRC()
        let separator = rc.isEmpty || rc.hasSuffix("\n") ? "" : "\n"
        try (rc + separator + CommandShell.rcLine + "\n").write(to: rcFile, atomically: true, encoding: .utf8)
    }

    static func remove() throws {
        if let rc = try? String(contentsOf: rcFile, encoding: .utf8), rc.contains(CommandShell.marker) {
            try backupRC()
            let kept = rc.components(separatedBy: "\n").filter { !$0.contains(CommandShell.marker) }
            try kept.joined(separator: "\n").write(to: rcFile, atomically: true, encoding: .utf8)
        }
        try? FileManager.default.removeItem(at: scriptFile)
    }

    static func refreshIfInstalled(executable: String) {
        guard isInstalled() else { return }
        let current = try? String(contentsOf: scriptFile, encoding: .utf8)
        guard current != CommandShell.script(executable: executable) else { return }
        try? writeScript(executable: executable)
    }

    private static func writeScript(executable: String) throws {
        try FileManager.default.createDirectory(at: scriptFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try CommandShell.script(executable: executable).write(to: scriptFile, atomically: true, encoding: .utf8)
    }

    private static func backupRC() throws {
        let backup = rcFile.appendingPathExtension(CommandShell.backupExtension)
        guard FileManager.default.fileExists(atPath: rcFile.path), !FileManager.default.fileExists(atPath: backup.path) else { return }
        try FileManager.default.copyItem(at: rcFile, to: backup)
    }
}
