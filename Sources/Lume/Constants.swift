import SwiftUI

enum Metrics {
    static let restingEarWidth: CGFloat = 8
    static let eyeEarPadding: CGFloat = 7
    static let fallbackNotchWidth: CGFloat = 120
    static let fallbackNotchMinHeight: CGFloat = 30
    static let maxNotchSize = CGSize(width: 640, height: 220)
}

enum NotchCurve {
    static let baseCornerRadius: CGFloat = 8
    static let cornerRadiusPerHeight: CGFloat = 0.17
    static let maxCornerRadius: CGFloat = 32
    static let baseFlare: CGFloat = 6
    static let flarePerHeight: CGFloat = 0.115
    static let maxFlare: CGFloat = 22

    static func cornerRadius(forHeight height: CGFloat) -> CGFloat {
        min(baseCornerRadius + height * cornerRadiusPerHeight, maxCornerRadius)
    }

    static func flare(forHeight height: CGFloat) -> CGFloat {
        min(baseFlare + height * flarePerHeight, maxFlare)
    }
}

enum NotchMotion {
    static let resize = Animation.spring(response: 0.5, dampingFraction: 0.72)
    static let close = Animation.spring(response: 0.4, dampingFraction: 0.9)
}

enum NotchHover {
    static let openSize = CGSize(width: 420, height: 140)
    static let openDelay: Double = 0.12
    static let closeDelay: Double = 0.35
    static let restingSlop: CGFloat = 6
}

enum OwlShape {
    static let heightRatio: CGFloat = 96.0 / 112.0
    static let innerScale = CGSize(width: 0.955, height: 0.905)
    static let eyeCenters = [CGPoint(x: 0.366, y: 0.49), CGPoint(x: 0.634, y: 0.49)]
    static let eyeSize = CGSize(width: 0.125, height: 0.229)
    static let rimFadeStart: CGFloat = 0.35
    static let rimFadeEnd: CGFloat = 0.9
    static let rimColors = [NotchRim.amber, NotchRim.coral, NotchRim.magenta]
    static let bodyColors = [
        Color(red: 58 / 255, green: 59 / 255, blue: 70 / 255),
        Color(red: 30 / 255, green: 31 / 255, blue: 38 / 255),
        Color(red: 18 / 255, green: 18 / 255, blue: 23 / 255)
    ]
}

enum OpenLayout {
    static let mascotWidth: CGFloat = 48
    static let mascotOrigin = CGPoint(x: 18, y: 8)
    static let mascotAppearScale: CGFloat = 0.6
    static let headerTop: CGFloat = 13
    static let titleLeading: CGFloat = 76
    static let dateTrailing: CGFloat = 22
    static let headerFontSize: CGFloat = 13
    static let clockTop: CGFloat = 40
    static let clockFontSize: CGFloat = 44
    static let dotsBottom: CGFloat = 12
    static let dotSize: CGFloat = 4
    static let activeDotWidth: CGFloat = 15
    static let dotSpacing: CGFloat = 4.5
    static let dotHitPadding: CGFloat = 6
    static let inactiveDotOpacity: Double = 0.4
    static let title = "Lume"
    static let noModules = "Nenhum módulo ligado. Use a engrenagem para ligar."
    static let localeID = "pt_BR"
    static let dateFormat = "EEE, d MMM"
    static let secondaryOpacity: Double = 0.6
    static let contentFade = Animation.easeOut(duration: 0.25).delay(0.1)
}

enum MeetingLinkPattern {
    static let regex = #"https://(?:teams\.microsoft\.com/l/meetup-join|teams\.live\.com/meet|meet\.google\.com|[\w.-]*zoom\.us/(?:j|my|w))[^\s<>"')\]]*"#
    static let providers = ["teams": "Teams", "meet.google": "Meet", "zoom": "Zoom"]
}

enum AlertLayout {
    static let size = CGSize(width: 400, height: 60)
    static let textRefresh: TimeInterval = 15
    static let belowCameraHeight: CGFloat = 48
    static let verticalPadding: CGFloat = 11
    static let duration: Double = 8
    static let leaveDelay: Double = 2
    static let queueGap: Double = 0.6
    static let checkInterval: TimeInterval = 15
    static let firingWindow: TimeInterval = 60
    static let mascotWidth: CGFloat = 36
    static let horizontalPadding: CGFloat = 12
    static let spacing: CGFloat = 10
    static let titleSize: CGFloat = 13
    static let subtitleSize: CGFloat = 11
    static let buttonHeight: CGFloat = 22
    static let buttonFontSize: CGFloat = 11
    static let selectableMinutes = [1, 5, 10, 15, 30]
}

enum MeetingLayout {
    static let refreshInterval: TimeInterval = 15
    static let nextWindow: TimeInterval = 30 * 60
    static let live = Color(red: 48 / 255, green: 199 / 255, blue: 89 / 255)
    static let eyeSize = CGSize(width: 7, height: 11)
    static let eyeGap: CGFloat = 4
    static let dotSize: CGFloat = 6
    static let fontSize: CGFloat = 11.5
    static let spacing: CGFloat = 7
    static let horizontalPadding: CGFloat = 12
    static let compactWidth: CGFloat = 150
    static let endingWidth: CGFloat = 330
    static let notchEarExtra: CGFloat = 70
    static let notchEndingEarExtra: CGFloat = 150
}

enum MeetingText {
    static let now = "agora"

    static func remaining(_ minutes: Int) -> String {
        "\(minutes) min"
    }

    static func next(_ event: CalendarEvent) -> String {
        "próximo: \(event.title) às \(WeekText.time(event.start, calendar: .current))"
    }

    static func accessibility(_ meeting: MeetingStatus) -> String {
        "\(meeting.event.title), faltam \(meeting.remainingMinutes) min"
    }
}

enum AlertSound {
    static let defaultName = "Glass"
    static let choices = ["Glass", "Ping", "Pop", "Purr", "Tink", "Hero"]
}

enum AlertShake {
    static let delay: Double = 0.45
    static let bounces = 2
    static let depth: CGFloat = 4
    static let downDuration: Double = 0.12
    static let pause: Double = 0.22
    static let settle = Animation.spring(response: 0.28, dampingFraction: 0.55)
}

enum AlertText {
    static let startedNow = "Começou agora"
    static let join = "Entrar"
    static let later = "Depois"
    static let close = "Fechar"
}

enum SettingsLayout {
    static let size = CGSize(width: 640, height: 480)
    static let sidebarWidth: CGFloat = 180
    static let gearSize: CGFloat = 12
    static let gearInset: CGFloat = 18
}

enum PageSwipe {
    static let threshold: CGFloat = 40
    static let idleReset: TimeInterval = 0.4
}

enum ConfigFile {
    static let directory = ".config/lume"
    static let name = "config.json"
}

enum WeekModule {
    static let refreshInterval: TimeInterval = 300
}

enum WeekLayout {
    static let horizontalPadding: CGFloat = 22
    static let headerTop: CGFloat = 12
    static let stripTop: CGFloat = 6
    static let nextRowTop: CGFloat = 6
    static let titleSize: CGFloat = 12.5
    static let metaSize: CGFloat = 12
    static let rowSize: CGFloat = 11.5
    static let rowHeight: CGFloat = 22
    static let rowSpacing: CGFloat = 6
    static let secondaryOpacity: Double = 0.55
    static let circle: CGFloat = 22
    static let miniCircle: CGFloat = 20
    static let miniLetterSize: CGFloat = 8.5
    static let miniNumberSize: CGFloat = 10.5
    static let dot: CGFloat = 4
    static let maxDots = 3
    static let detailSpacing: CGFloat = 14
    static let detailHeaderTop: CGFloat = 11
    static let detailHeaderGap: CGFloat = 8
    static let listWidth: CGFloat = 196
    static let listHeight: CGFloat = 78
    static let miniWidth: CGFloat = 166
    static let miniVerticalPadding: CGFloat = 4
    static let verticalDotsHeight: CGFloat = dot * CGFloat(maxDots) + 2 * CGFloat(maxDots - 1)
    static let cardOpacity: Double = 0.06
}

enum NotchRim {
    static let bottomThickness: CGFloat = 2.5
    static let sideThickness: CGFloat = 1.2
    static let amber = Color(red: 1, green: 179 / 255, blue: 107 / 255)
    static let coral = Color(red: 1, green: 106 / 255, blue: 77 / 255)
    static let magenta = Color(red: 214 / 255, green: 51 / 255, blue: 108 / 255)
    static let colors = [amber, coral, magenta, coral, amber]
    static let flowPeriod: Double = 6
    static let fadeStart: CGFloat = 0.2
    static let fadeEnd: CGFloat = 0.85
}

enum OwlEyes {
    static let widthRatio: CGFloat = 0.3
    static let heightRatio: CGFloat = 0.46
    static let centeredSpacingRatio: CGFloat = 0.8
    static let blinkInterval: Double = 4.2
    static let blinkDuration: Double = 0.09
    static let color = Color.white
    static let glowOpacity: Double = 0.7
    static let glowRadius: CGFloat = 1.5
    static let haloOpacity: Double = 0.22
    static let haloRadius: CGFloat = 5

    static func size(forNotchHeight height: CGFloat) -> CGSize {
        CGSize(width: (height * widthRatio).rounded(), height: (height * heightRatio).rounded())
    }
}

enum LaunchOptions {
    static let demoAlert = "LUME_DEMO_ALERT"
    static let demoMeeting = "LUME_DEMO_MEETING"
}
