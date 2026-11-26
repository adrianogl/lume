import AppKit
import SwiftUI

struct RimGradientView: NSViewRepresentable {
    func makeNSView(context: Context) -> RimGradientNSView {
        RimGradientNSView()
    }

    func updateNSView(_ view: RimGradientNSView, context: Context) {}
}

final class RimGradientNSView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private let gradient = CAGradientLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true

        gradient.colors = NotchRim.colors.map { NSColor($0).cgColor }
        gradient.startPoint = CGPoint(x: -1, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)

        layer?.addSublayer(gradient)
        startFlowing()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        CATransaction.commit()
    }

    private func startFlowing() {
        let start = CABasicAnimation(keyPath: "startPoint")
        start.fromValue = CGPoint(x: -1, y: 0.5)
        start.toValue = CGPoint(x: 0, y: 0.5)
        let end = CABasicAnimation(keyPath: "endPoint")
        end.fromValue = CGPoint(x: 1, y: 0.5)
        end.toValue = CGPoint(x: 2, y: 0.5)

        let group = CAAnimationGroup()
        group.animations = [start, end]
        group.duration = NotchRim.flowPeriod / 2
        group.autoreverses = true
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradient.add(group, forKey: "flow")
    }
}
