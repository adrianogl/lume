import SwiftUI

enum SVGPath {
    static func parse(_ data: String) -> Path {
        var path = Path()
        var tokens = Tokenizer(data)
        var current = CGPoint.zero
        var start = CGPoint.zero
        var command: Character = "M"

        while let next = tokens.peekCommand() ?? (tokens.hasNumber ? command : nil) {
            if tokens.peekCommand() != nil { tokens.skipCommand() }
            command = next
            let relative = command.isLowercase
            let base = relative ? current : .zero
            switch command.uppercased() {
            case "M":
                guard let point = tokens.point(base) else { return path }
                path.move(to: point)
                current = point
                start = point
                command = relative ? "l" : "L"
            case "L":
                guard let point = tokens.point(base) else { return path }
                path.addLine(to: point)
                current = point
            case "H":
                guard let x = tokens.number() else { return path }
                current = CGPoint(x: (relative ? current.x : 0) + x, y: current.y)
                path.addLine(to: current)
            case "V":
                guard let y = tokens.number() else { return path }
                current = CGPoint(x: current.x, y: (relative ? current.y : 0) + y)
                path.addLine(to: current)
            case "C":
                guard let c1 = tokens.point(base), let c2 = tokens.point(base), let end = tokens.point(base) else { return path }
                path.addCurve(to: end, control1: c1, control2: c2)
                current = end
            case "Z":
                path.closeSubpath()
                current = start
            default:
                return path
            }
        }
        return path
    }

    private struct Tokenizer {
        private let chars: [Character]
        private var index = 0

        init(_ text: String) { chars = Array(text) }

        private mutating func skipSeparators() {
            while index < chars.count, chars[index] == " " || chars[index] == "," || chars[index] == "\n" { index += 1 }
        }

        mutating func peekCommand() -> Character? {
            skipSeparators()
            guard index < chars.count, chars[index].isLetter else { return nil }
            return chars[index]
        }

        mutating func skipCommand() { index += 1 }

        var hasNumber: Bool {
            var probe = self
            probe.skipSeparators()
            guard probe.index < probe.chars.count else { return false }
            let char = probe.chars[probe.index]
            return char.isNumber || char == "-" || char == "."
        }

        mutating func number() -> CGFloat? {
            skipSeparators()
            var text = ""
            var seenDot = false
            while index < chars.count {
                let char = chars[index]
                if char.isNumber {
                    text.append(char)
                } else if char == "-" && text.isEmpty {
                    text.append(char)
                } else if char == "." && !seenDot {
                    seenDot = true
                    text.append(char)
                } else {
                    break
                }
                index += 1
            }
            return Double(text).map { CGFloat($0) }
        }

        mutating func point(_ base: CGPoint) -> CGPoint? {
            guard let x = number(), let y = number() else { return nil }
            return CGPoint(x: base.x + x, y: base.y + y)
        }
    }
}
