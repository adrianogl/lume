import SwiftUI

@MainActor
final class NotchModel: ObservableObject {
    @Published private(set) var size: CGSize
    @Published private(set) var isOpen = false
    @Published private(set) var pages: [NotchPage] = []
    @Published private(set) var pageIndex = 0
    let restingSize: CGSize
    var openSettings: () -> Void = {}

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
        showPage(pageIndex + (forward ? 1 : -1))
    }
    private var hoverTask: Task<Void, Never>?

    init(restingSize: CGSize) {
        self.restingSize = restingSize
        self.size = restingSize
    }

    var isResting: Bool { size == restingSize }

    func resize(toFit content: CGSize) {
        let target = CGSize(
            width: min(max(content.width, restingSize.width), Metrics.maxNotchSize.width),
            height: min(max(content.height, restingSize.height), Metrics.maxNotchSize.height)
        )
        guard target != size else { return }
        withAnimation(NotchMotion.resize) { size = target }
    }

    func rest() {
        resize(toFit: restingSize)
    }

    func hoverChanged(_ inside: Bool) {
        guard inside != isOpen || hoverTask != nil else { return }
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

    private func open() {
        withAnimation(NotchMotion.resize) { isOpen = true }
        resize(toFit: NotchHover.openSize)
    }

    private func close() {
        withAnimation(NotchMotion.close) { isOpen = false }
        rest()
    }
}
