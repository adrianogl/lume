import AppKit
import SwiftUI

struct RimGradientView: NSViewRepresentable {
    let topRadius: CGFloat
    let bottomRadius: CGFloat

    func makeNSView(context: Context) -> RimGradientNSView {
        RimGradientNSView()
    }

    func updateNSView(_ view: RimGradientNSView, context: Context) {
        view.update(topRadius: topRadius, bottomRadius: bottomRadius)
    }
}

final class RimGradientNSView: NSView {
    private let gradient = CAGradientLayer()
    private let fade = CAGradientLayer()
    private let shape = CAShapeLayer()
    private var topRadius: CGFloat = 0
    private var bottomRadius: CGFloat = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true

        gradient.colors = NotchRim.colors.map { NSColor($0).cgColor }
        gradient.startPoint = CGPoint(x: -1, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)

        fade.colors = [NSColor.clear.cgColor, NSColor.black.cgColor]
        fade.locations = [NSNumber(value: Double(NotchRim.fadeStart)), NSNumber(value: Double(NotchRim.fadeEnd))]
        fade.startPoint = CGPoint(x: 0.5, y: 1)
        fade.endPoint = CGPoint(x: 0.5, y: 0)
        gradient.mask = fade

        layer?.addSublayer(gradient)
        layer?.mask = shape
        startFlowing()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(topRadius: CGFloat, bottomRadius: CGFloat) {
        self.topRadius = topRadius
        self.bottomRadius = bottomRadius
        needsLayout = true
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        fade.frame = bounds
        shape.frame = bounds
        let flipToLayerSpace = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -bounds.height)
        shape.path = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
            .path(in: bounds)
            .applying(flipToLayerSpace)
            .cgPath
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
