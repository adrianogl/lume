import Foundation

enum MeetingLink {
    private static let regex = try? NSRegularExpression(
        pattern: AgendaConfig.meetingLinkPattern,
        options: [.caseInsensitive]
    )

    static func find(in texts: [String?]) -> URL? {
        guard let regex else { return nil }
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let swiftRange = Range(match.range, in: text),
               let url = URL(string: String(text[swiftRange])) {
                return url
            }
        }
        return nil
    }
}
