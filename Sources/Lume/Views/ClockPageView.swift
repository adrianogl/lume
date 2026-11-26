import SwiftUI

struct ClockPageView: View {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: OpenLayout.localeID)
        formatter.dateFormat = OpenLayout.dateFormat
        return formatter
    }()

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            ZStack(alignment: .top) {
                HStack {
                    Text(OpenLayout.title)
                        .font(.system(size: OpenLayout.headerFontSize, weight: .semibold))
                        .padding(.leading, OpenLayout.titleLeading)
                    Spacer(minLength: 0)
                    Text(Self.dateFormatter.string(from: timeline.date).replacingOccurrences(of: ".", with: ""))
                        .font(.system(size: OpenLayout.headerFontSize))
                        .monospacedDigit()
                        .opacity(OpenLayout.secondaryOpacity)
                        .padding(.trailing, OpenLayout.dateTrailing)
                }
                .padding(.top, OpenLayout.headerTop)

                Text(timeline.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.system(size: OpenLayout.clockFontSize, weight: .bold))
                    .monospacedDigit()
                    .padding(.top, OpenLayout.clockTop)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
