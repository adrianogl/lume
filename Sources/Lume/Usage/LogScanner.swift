import Foundation

final class LogScanner: @unchecked Sendable {
    private struct CachedFile {
        let modified: Date
        let size: Int
        let entries: [TokenEntry]
    }

    private var cache: [String: CachedFile] = [:]
    private let lock = NSLock()

    func scan(_ account: Account, since: Date) -> [TokenEntry] {
        lock.lock()
        defer { lock.unlock() }

        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        guard let enumerator = fm.enumerator(at: account.projectsDir, includingPropertiesForKeys: keys) else { return [] }

        var files: [(url: URL, modified: Date, size: Int)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  modified >= since
            else { continue }
            files.append((url, modified, values.fileSize ?? 0))
        }

        let stale = files.filter { file in
            guard let cached = cache[file.url.path] else { return true }
            return cached.modified != file.modified || cached.size != file.size
        }
        var parsed = [[TokenEntry]](repeating: [], count: stale.count)
        parsed.withUnsafeMutableBufferPointer { slots in
            let slots = slots
            DispatchQueue.concurrentPerform(iterations: stale.count) { i in
                slots[i] = LineParser.parse(stale[i].url)
            }
        }
        for (file, entries) in zip(stale, parsed) {
            cache[file.url.path] = CachedFile(modified: file.modified, size: file.size, entries: entries)
        }

        let current = Set(files.map(\.url.path))
        cache = cache.filter { current.contains($0.key) }

        var seenKeys = Set<String>()
        var result: [TokenEntry] = []
        for file in files {
            for entry in cache[file.url.path]?.entries ?? [] where entry.date >= since && seenKeys.insert(entry.key).inserted {
                result.append(entry)
            }
        }
        return result
    }
}

private enum LineParser {
    private static let assistant = Array("\"type\":\"assistant\"".utf8)
    private static let usage = Array("\"usage\":{".utf8)
    private static let timestamp = Array("\"timestamp\":\"".utf8)
    private static let messageId = Array("\"id\":\"msg_".utf8)
    private static let requestId = Array("\"requestId\":\"".utf8)
    private static let usageFields = ["input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"]

    static func parse(_ url: URL) -> [TokenEntry] {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return [] }
        var entries: [TokenEntry] = []

        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            let total = raw.count
            var lineStart = 0
            while lineStart < total {
                let remaining = total - lineStart
                let newline = memchr(base + lineStart, Int32(UInt8(ascii: "\n")), remaining)
                let lineEnd = newline.map { base.distance(to: UnsafeRawPointer($0)) } ?? total
                if let entry = entry(base + lineStart, length: lineEnd - lineStart) {
                    entries.append(entry)
                }
                lineStart = lineEnd + 1
            }
        }
        return entries
    }

    private static func entry(_ line: UnsafeRawPointer, length: Int) -> TokenEntry? {
        guard find(assistant, in: line, length: length) != nil,
              let usageAt = find(usage, in: line, length: length),
              let usageData = object(line, length: length, from: usageAt + usage.count - 1),
              let fields = try? JSONSerialization.jsonObject(with: usageData) as? [String: Any],
              let stamp = string(after: timestamp, in: line, length: length),
              let date = DateParsing.iso(stamp)
        else { return nil }

        let tokens = usageFields.reduce(0) { $0 + ((fields[$1] as? Int) ?? 0) }
        guard tokens > 0 else { return nil }

        let message = string(after: messageId, in: line, length: length) ?? UUID().uuidString
        let request = string(after: requestId, in: line, length: length) ?? ""
        return TokenEntry(key: message + ":" + request, date: date, tokens: tokens)
    }

    private static func find(_ needle: [UInt8], in line: UnsafeRawPointer, length: Int) -> Int? {
        needle.withUnsafeBytes { n in
            memmem(line, length, n.baseAddress, n.count).map { line.distance(to: UnsafeRawPointer($0)) }
        }
    }

    private static func string(after key: [UInt8], in line: UnsafeRawPointer, length: Int) -> String? {
        guard let at = find(key, in: line, length: length) else { return nil }
        let start = at + key.count
        guard start < length,
              let quote = memchr(line + start, Int32(UInt8(ascii: "\"")), length - start)
        else { return nil }
        let end = line.distance(to: UnsafeRawPointer(quote))
        return String(decoding: UnsafeRawBufferPointer(start: line + start, count: end - start), as: UTF8.self)
    }

    private static func object(_ line: UnsafeRawPointer, length: Int, from start: Int) -> Data? {
        let bytes = line.assumingMemoryBound(to: UInt8.self)
        var depth = 0
        var index = start
        while index < length {
            switch bytes[index] {
            case UInt8(ascii: "{"): depth += 1
            case UInt8(ascii: "}"):
                depth -= 1
                if depth == 0 { return Data(bytes: line + start, count: index - start + 1) }
            default: break
            }
            index += 1
        }
        return nil
    }
}
