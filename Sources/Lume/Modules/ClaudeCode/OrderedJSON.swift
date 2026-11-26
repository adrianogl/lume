import Foundation

indirect enum OrderedJSON: Equatable {
    case object([(key: String, value: OrderedJSON)])
    case array([OrderedJSON])
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    struct ParseError: Error {}

    static func == (lhs: OrderedJSON, rhs: OrderedJSON) -> Bool {
        switch (lhs, rhs) {
        case let (.object(a), .object(b)): a.count == b.count && zip(a, b).allSatisfy { $0.key == $1.key && $0.value == $1.value }
        case let (.array(a), .array(b)): a == b
        case let (.string(a), .string(b)): a == b
        case let (.number(a), .number(b)): a == b
        case let (.bool(a), .bool(b)): a == b
        case (.null, .null): true
        default: false
        }
    }

    static func parse(_ text: String) throws -> OrderedJSON {
        var reader = Reader(scalars: Array(text.unicodeScalars))
        let value = try reader.value()
        reader.skipSpace()
        guard reader.isAtEnd else { throw ParseError() }
        return value
    }

    static func from(_ value: Any) -> OrderedJSON {
        switch value {
        case let dictionary as [String: Any]:
            return .object(dictionary.keys.sorted().map { (key: $0, value: from(dictionary[$0] as Any)) })
        case let array as [Any]:
            return .array(array.map(from))
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
            return .number(number.stringValue)
        default:
            return .null
        }
    }

    func merged(with value: Any) -> OrderedJSON {
        let incoming = OrderedJSON.from(value)
        switch (self, value) {
        case let (.object(pairs), dictionary as [String: Any]):
            var result = pairs.compactMap { pair -> (key: String, value: OrderedJSON)? in
                guard let new = dictionary[pair.key] else { return nil }
                return (pair.key, pair.value.merged(with: new))
            }
            let existing = Set(pairs.map(\.key))
            for key in dictionary.keys.sorted() where !existing.contains(key) {
                result.append((key, OrderedJSON.from(dictionary[key] as Any)))
            }
            return .object(result)
        case let (.array(items), array as [Any]):
            var unused = items
            return .array(array.map { element in
                let normalized = OrderedJSON.from(element)
                if let match = unused.firstIndex(where: { $0.sortedKeys == normalized }) {
                    return unused.remove(at: match)
                }
                return normalized
            })
        case (.number(let raw), let number as NSNumber) where CFGetTypeID(number) != CFBooleanGetTypeID():
            return Double(raw) == number.doubleValue ? self : incoming
        default:
            return incoming
        }
    }

    var sortedKeys: OrderedJSON {
        switch self {
        case .object(let pairs): .object(pairs.sorted { $0.key < $1.key }.map { ($0.key, $0.value.sortedKeys) })
        case .array(let items): .array(items.map(\.sortedKeys))
        case .number(let raw): .number(Double(raw).map { NSNumber(value: $0).stringValue } ?? raw)
        default: self
        }
    }

    func serialized(level: Int = 0) -> String {
        let pad = String(repeating: "  ", count: level + 1)
        let close = String(repeating: "  ", count: level)
        switch self {
        case .object(let pairs):
            guard !pairs.isEmpty else { return "{}" }
            let body = pairs.map { "\(pad)\(Self.quote($0.key)): \($0.value.serialized(level: level + 1))" }
            return "{\n" + body.joined(separator: ",\n") + "\n\(close)}"
        case .array(let items):
            guard !items.isEmpty else { return "[]" }
            let body = items.map { pad + $0.serialized(level: level + 1) }
            return "[\n" + body.joined(separator: ",\n") + "\n\(close)]"
        case .string(let text): return Self.quote(text)
        case .number(let raw): return raw
        case .bool(let flag): return flag ? "true" : "false"
        case .null: return "null"
        }
    }

    private static func quote(_ text: String) -> String {
        var out = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }
}

private struct Reader {
    let scalars: [Unicode.Scalar]
    var index = 0

    var isAtEnd: Bool { index >= scalars.count }

    mutating func skipSpace() {
        while !isAtEnd, [" ", "\n", "\r", "\t"].contains(scalars[index]) { index += 1 }
    }

    mutating func value() throws -> OrderedJSON {
        skipSpace()
        guard !isAtEnd else { throw OrderedJSON.ParseError() }
        switch scalars[index] {
        case "{": return try object()
        case "[": return try array()
        case "\"": return .string(try string())
        case "t": try literal("true"); return .bool(true)
        case "f": try literal("false"); return .bool(false)
        case "n": try literal("null"); return .null
        default: return .number(try number())
        }
    }

    private mutating func object() throws -> OrderedJSON {
        index += 1
        var pairs: [(key: String, value: OrderedJSON)] = []
        skipSpace()
        if !isAtEnd, scalars[index] == "}" { index += 1; return .object(pairs) }
        while true {
            skipSpace()
            guard !isAtEnd, scalars[index] == "\"" else { throw OrderedJSON.ParseError() }
            let key = try string()
            skipSpace()
            try expect(":")
            pairs.append((key, try value()))
            skipSpace()
            if try next() == "}" { return .object(pairs) }
        }
    }

    private mutating func array() throws -> OrderedJSON {
        index += 1
        var items: [OrderedJSON] = []
        skipSpace()
        if !isAtEnd, scalars[index] == "]" { index += 1; return .array(items) }
        while true {
            items.append(try value())
            skipSpace()
            if try next() == "]" { return .array(items) }
        }
    }

    private mutating func next() throws -> Unicode.Scalar {
        guard !isAtEnd else { throw OrderedJSON.ParseError() }
        let scalar = scalars[index]
        guard scalar == "," || scalar == "}" || scalar == "]" else { throw OrderedJSON.ParseError() }
        index += 1
        return scalar
    }

    private mutating func expect(_ scalar: Unicode.Scalar) throws {
        guard !isAtEnd, scalars[index] == scalar else { throw OrderedJSON.ParseError() }
        index += 1
    }

    private mutating func literal(_ word: String) throws {
        for scalar in word.unicodeScalars { try expect(scalar) }
    }

    private mutating func number() throws -> String {
        let start = index
        while !isAtEnd, "+-0123456789.eE".unicodeScalars.contains(scalars[index]) { index += 1 }
        guard index > start else { throw OrderedJSON.ParseError() }
        return String(String.UnicodeScalarView(scalars[start..<index]))
    }

    private mutating func string() throws -> String {
        index += 1
        var out = String.UnicodeScalarView()
        while !isAtEnd {
            let scalar = scalars[index]
            index += 1
            if scalar == "\"" { return String(out) }
            guard scalar == "\\" else { out.append(scalar); continue }
            guard !isAtEnd else { break }
            let escaped = scalars[index]
            index += 1
            switch escaped {
            case "n": out.append("\n")
            case "r": out.append("\r")
            case "t": out.append("\t")
            case "b": out.append("\u{08}")
            case "f": out.append("\u{0C}")
            case "u":
                var code = try hex()
                if (0xD800..<0xDC00).contains(code), index + 1 < scalars.count, scalars[index] == "\\", scalars[index + 1] == "u" {
                    index += 2
                    let low = try hex()
                    code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
                }
                if let value = Unicode.Scalar(code) { out.append(value) }
            default: out.append(escaped)
            }
        }
        throw OrderedJSON.ParseError()
    }

    private mutating func hex() throws -> UInt32 {
        guard index + 4 <= scalars.count, let code = UInt32(String(String.UnicodeScalarView(scalars[index..<index + 4])), radix: 16) else {
            throw OrderedJSON.ParseError()
        }
        index += 4
        return code
    }
}
