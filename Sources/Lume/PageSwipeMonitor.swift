import AppKit

@MainActor
final class PageSwipeMonitor {
    private let model: NotchModel
    private var monitor: Any?
    private var accumulated: CGFloat = 0
    private var hasTurned = false
    private var lastEventTime: TimeInterval = 0

    init(model: NotchModel) {
        self.model = model
    }

    func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            let gesture = ScrollGesture(event)
            let consumed = MainActor.assumeIsolated { self.handle(gesture) }
            return consumed ? nil : event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ gesture: ScrollGesture) -> Bool {
        guard model.isOpen, model.pages.count > 1 else { return false }
        let idle = gesture.timestamp - lastEventTime > PageSwipe.idleReset
        lastEventTime = gesture.timestamp
        if gesture.isStarting || (gesture.hasNoPhase && idle) {
            accumulated = 0
            hasTurned = false
        }
        guard !gesture.isMomentum else { return hasTurned }
        guard abs(gesture.deltaX) > abs(gesture.deltaY) else { return false }

        accumulated += gesture.deltaX
        if !hasTurned, abs(accumulated) >= PageSwipe.threshold {
            hasTurned = true
            model.turnPage(forward: accumulated < 0)
        }
        if gesture.isEnding {
            accumulated = 0
        }
        return true
    }
}

private struct ScrollGesture: Sendable {
    let deltaX: CGFloat
    let deltaY: CGFloat
    let isStarting: Bool
    let isEnding: Bool
    let isMomentum: Bool
    let hasNoPhase: Bool
    let timestamp: TimeInterval

    init(_ event: NSEvent) {
        hasNoPhase = event.phase.isEmpty && event.momentumPhase.isEmpty
        timestamp = event.timestamp
        deltaX = event.scrollingDeltaX
        deltaY = event.scrollingDeltaY
        isStarting = event.phase == .began || event.phase == .mayBegin
        isEnding = event.phase == .ended || event.phase == .cancelled
        isMomentum = !event.momentumPhase.isEmpty
    }
}
