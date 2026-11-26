import AppKit
import SwiftUI

@MainActor
final class NotchModel: ObservableObject {
    @Published private(set) var size: CGSize
    @Published private(set) var isOpen = false
    @Published private(set) var pages: [NotchPage] = []
    @Published private(set) var pageIndex = 0
    @Published private(set) var alert: EventAlert?
    @Published private(set) var meeting: MeetingStatus?
    @Published private(set) var isMusicActive = false
    var alertFeedback = EventAlertsConfig()
    let restingSize: CGSize
    let contentTopInset: CGFloat
    var openSettings: () -> Void = {}
    private var hoverTask: Task<Void, Never>?
    private var alertTask: Task<Void, Never>?
    private var alertQueue: [EventAlert] = []
    private var isHovering = false

    init(restingSize: CGSize, contentTopInset: CGFloat) {
        self.restingSize = restingSize
        self.contentTopInset = contentTopInset
        self.size = restingSize
    }

    private var alertSize: CGSize {
        let contentHeight = contentTopInset > 0 ? AlertLayout.belowCameraHeight : AlertLayout.size.height
        return CGSize(width: AlertLayout.size.width, height: contentTopInset + contentHeight)
    }

    var currentPage: NotchPage? {
        pages.indices.contains(pageIndex) ? pages[pageIndex] : nil
    }

    func setPages(_ newPages: [NotchPage]) {
        let current = currentPage
        pages = newPages
        pageIndex = current.flatMap { newPages.firstIndex(of: $0) } ?? 0
    }

    func showPage(_ index: Int) {
        guard pages.indices.contains(index) else { return }
        withAnimation(.easeOut(duration: 0.2)) { pageIndex = index }
    }

    func turnPage(forward: Bool) {
        guard !pages.isEmpty else { return }
        showPage((pageIndex + (forward ? 1 : -1) + pages.count) % pages.count)
    }

    func resize(toFit content: CGSize) {
        let target = CGSize(
            width: min(max(content.width, restingSize.width), Metrics.maxNotchSize.width),
            height: min(max(content.height, restingSize.height), Metrics.maxNotchSize.height)
        )
        guard target != size else { return }
        withAnimation(NotchMotion.resize) { size = target }
    }

    func rest() {
        resize(toFit: baseSize)
    }

    var baseSize: CGSize {
        guard let meeting else {
            if isMusicActive, contentTopInset > 0 {
                return CGSize(width: restingSize.width + MusicLayout.notchEarExtra * 2, height: restingSize.height)
            }
            return restingSize
        }
        let physical = contentTopInset > 0
        if physical {
            let extra = meeting.next == nil ? MeetingLayout.notchEarExtra : MeetingLayout.notchEndingEarExtra
            return CGSize(width: restingSize.width + extra * 2, height: restingSize.height)
        }
        let width = meeting.next == nil ? MeetingLayout.compactWidth : MeetingLayout.endingWidth
        return CGSize(width: max(width, restingSize.width), height: restingSize.height)
    }

    func setMusicActive(_ active: Bool) {
        guard active != isMusicActive else { return }
        withAnimation(NotchMotion.resize) { isMusicActive = active }
        if !isOpen, alert == nil {
            rest()
        }
    }

    func setMeeting(_ status: MeetingStatus?) {
        guard status != meeting else { return }
        withAnimation(NotchMotion.resize) { meeting = status }
        if !isOpen, alert == nil {
            rest()
        }
    }

    func hoverChanged(_ inside: Bool) {
        guard inside != isHovering else { return }
        isHovering = inside

        if alert != nil {
            if inside {
                alertTask?.cancel()
            } else {
                scheduleAlertDismiss(after: AlertLayout.leaveDelay)
            }
            return
        }

        hoverTask?.cancel()
        hoverTask = nil
        guard inside != isOpen else { return }
        let delay = inside ? NotchHover.openDelay : NotchHover.closeDelay
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.hoverTask = nil
            inside ? self.open() : self.close()
        }
    }

    func present(_ newAlert: EventAlert) {
        alertQueue.append(newAlert)
        showNextAlert()
    }

    func fitAlert(contentHeight: CGFloat) {
        guard alert != nil, contentHeight > 0 else { return }
        let base = alertSize
        let height = max(base.height, contentTopInset + contentHeight.rounded(.up))
        resize(toFit: CGSize(width: base.width, height: height))
    }

    func dismissAlert() {
        alertTask?.cancel()
        alertTask = nil
        withAnimation(NotchMotion.close) { alert = nil }
        rest()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(AlertLayout.queueGap))
            self?.showNextAlert()
        }
    }

    private func showNextAlert() {
        guard !isOpen, alert == nil, !alertQueue.isEmpty else { return }
        let next = alertQueue.removeFirst()
        withAnimation(NotchMotion.resize) { alert = next }
        resize(toFit: alertSize)
        announce()
        if !isHovering {
            scheduleAlertDismiss(after: AlertLayout.duration)
        }
    }

    private func announce() {
        let feedback = alertFeedback
        if !feedback.sound.isEmpty {
            NSSound(named: feedback.sound)?.play()
        }
        guard feedback.shake else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(AlertShake.delay))
            for _ in 0..<AlertShake.bounces {
                guard let self, self.alert != nil else { return }
                withAnimation(.easeOut(duration: AlertShake.downDuration)) { self.size.height += AlertShake.depth }
                try? await Task.sleep(for: .seconds(AlertShake.downDuration))
                withAnimation(AlertShake.settle) { self.size.height -= AlertShake.depth }
                try? await Task.sleep(for: .seconds(AlertShake.pause))
            }
        }
    }

    private func scheduleAlertDismiss(after delay: Double) {
        alertTask?.cancel()
        alertTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, !self.isHovering else { return }
            self.dismissAlert()
        }
    }

    private func open() {
        withAnimation(NotchMotion.resize) { isOpen = true }
        resize(toFit: NotchHover.openSize)
    }

    private func close() {
        withAnimation(NotchMotion.close) { isOpen = false }
        rest()
        showNextAlert()
    }
}
