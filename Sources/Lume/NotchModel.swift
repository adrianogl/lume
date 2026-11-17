import SwiftUI

@MainActor
final class NotchModel: ObservableObject {
    @Published var isOpen = false
    @Published var isPinned = false
    @Published var activeID: String
    @Published private(set) var alertHistory: [AlertRecord] = []
    @Published private(set) var unseenAlerts = 0
    @Published var showsAlertHistory = false {
        didSet {
            if showsAlertHistory { unseenAlerts = 0 }
        }
    }
    @Published var earID: String
    @Published var voice: VoiceState = .idle
    @Published var exchange: VoiceExchange?
    @Published var nowPlaying: NowPlaying?
    @Published private(set) var alert: NotchAlert?
    private var alertQueue: [NotchAlert] = []
    private var alertTask: Task<Void, Never>?
    @Published var glow = UnitPoint(x: 0.5, y: 0)

    @Published private(set) var categories: [LumeCategory]
    let notchSize: CGSize
    let hasPhysicalNotch: Bool
    var onMusicCommand: ((MusicCommand) -> Void)?
    private var hoverTask: Task<Void, Never>?

    init(categories: [LumeCategory], notchSize: CGSize, hasPhysicalNotch: Bool) {
        self.categories = categories
        self.notchSize = notchSize
        self.hasPhysicalNotch = hasPhysicalNotch
        activeID = categories.first?.id ?? ""
        earID = categories.first?.id ?? ""
    }

    var active: LumeCategory? { categories.first { $0.id == activeID } }
    var ear: LumeCategory? { categories.first { $0.id == earID } }

    var closedSize: CGSize {
        CGSize(width: notchSize.width + Metrics.earWidth * 2 + Metrics.earPadding * 2, height: notchSize.height)
    }

    var currentSize: CGSize {
        if isOpen { return Metrics.openSize }
        if alert != nil {
            return CGSize(width: closedSize.width + AlertConfig.extraWidth, height: closedSize.height + AlertConfig.height)
        }
        return closedSize
    }

    func present(_ newAlert: NotchAlert) {
        recordAlert(newAlert)
        alertQueue.append(newAlert)
        if alert == nil && alertTask == nil {
            showNextAlert()
        }
    }

    private func recordAlert(_ newAlert: NotchAlert) {
        alertHistory.insert(AlertRecord(date: Date(), alert: newAlert), at: 0)
        alertHistory = Array(alertHistory.prefix(AlertHistoryConfig.maxItems))
        if !(isOpen && showsAlertHistory) {
            unseenAlerts += 1
        }
    }

    func dismissAlert() {
        alertTask?.cancel()
        alertTask = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { alert = nil }
        showNextAlert(after: AlertConfig.gap)
    }

    private func showNextAlert(after delay: Double = 0) {
        guard !alertQueue.isEmpty else { return }
        alertTask = Task {
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled, !alertQueue.isEmpty else { return }
            let next = alertQueue.removeFirst()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { alert = next }
            try? await Task.sleep(for: .seconds(AlertConfig.duration))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { alert = nil }
            alertTask = nil
            showNextAlert(after: AlertConfig.gap)
        }
    }

    func hoverChanged(_ inside: Bool) {
        hoverTask?.cancel()
        if inside {
            guard !isOpen else { return }
            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Metrics.hoverOpenDelay))
                guard !Task.isCancelled else { return }
                open()
            }
        } else {
            guard !isPinned else { return }
            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Metrics.hoverCloseDelay))
                guard !Task.isCancelled else { return }
                close()
            }
        }
    }

    func open(pin: Bool = false) {
        if pin {
            hoverTask?.cancel()
            isPinned = true
        }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { isOpen = true }
    }

    func close() {
        hoverTask?.cancel()
        isPinned = false
        exchange = nil
        showsAlertHistory = false
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { isOpen = false }
        resetGlow()
    }

    func togglePin() {
        if isPinned {
            close()
        } else {
            activeID = earID
            open(pin: true)
        }
    }

    func show(categoryID: String) {
        hoverTask?.cancel()
        activeID = categoryID
        open(pin: true)
    }

    func update(_ category: LumeCategory) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
        } else {
            categories.append(category)
        }
    }

    func select(index: Int) {
        guard categories.indices.contains(index) else { return }
        activeID = categories[index].id
    }

    func moveGlow(to point: CGPoint) {
        let size = currentSize
        guard size.width > 0, size.height > 0 else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            glow = UnitPoint(x: point.x / size.width, y: point.y / size.height)
        }
    }

    func resetGlow() {
        withAnimation(.easeOut(duration: 0.4)) { glow = UnitPoint(x: 0.5, y: 0) }
    }
}
