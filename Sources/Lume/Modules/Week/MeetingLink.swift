import Foundation

enum MeetingLink {
    private static let regex = try? NSRegularExpression(pattern: MeetingLinkPattern.regex, options: [.caseInsensitive])

    static func find(in texts: [String?]) -> URL? {
        guard let regex else { return nil }
        for text in texts.compactMap({ $0 }) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let matchRange = Range(match.range, in: text),
               let url = URL(string: String(text[matchRange])) {
                return url
            }
        }
        return nil
    }

    static func provider(of url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        return MeetingLinkPattern.providers.first { host.contains($0.key) }?.value
    }
}
