import AppKit
import SwiftUI

struct EyesLayerView: NSViewRepresentable {
    let eyeSize: CGSize
    let centerDistance: CGFloat
    let isAmber: Bool
    let isBobbing: Bool

    func makeNSView(context: Context) -> EyesLayerNSView {
        EyesLayerNSView()
    }

    func updateNSView(_ view: EyesLayerNSView, context: Context) {
        view.configure(eyeSize: eyeSize, centerDistance: centerDistance, isAmber: isAmber, isBobbing: isBobbing)
    }
}

final class EyesLayerNSView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private let container = CALayer()
    private let eyes = [CAShapeLayer(), CAShapeLayer()]
    private var eyeSize: CGSize = .zero
    private var centerDistance: CGFloat = 0
    private var isBobbing = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(container)
        for (index, eye) in eyes.enumerated() {
            eye.shadowOffset = .zero
            eye.shadowRadius = ClosedLayout.eyeGlowRadius
            container.addSublayer(eye)
            blink(eye, delay: Double(index) * 0.02)
        }
        applyTint(amber: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(eyeSize: CGSize, centerDistance: CGFloat, isAmber: Bool, isBobbing: Bool) {
        self.eyeSize = eyeSize
        self.centerDistance = centerDistance
        applyTint(amber: isAmber)
        if isBobbing != self.isBobbing {
            self.isBobbing = isBobbing
            isBobbing ? startBob() : container.removeAnimation(forKey: "bob")
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        container.frame = bounds
        for (eye, sign) in zip(eyes, [-1.0, 1.0]) {
            let center = CGPoint(x: bounds.midX + CGFloat(sign) * centerDistance / 2, y: bounds.midY)
            eye.bounds = CGRect(origin: .zero, size: eyeSize)
            eye.position = center
            eye.path = CGPath(ellipseIn: CGRect(origin: .zero, size: eyeSize), transform: nil)
        }
        CATransaction.commit()
    }

    private func applyTint(amber: Bool) {
        let fill = amber ? ClosedLayout.amberEye : NSColor.white
        let glow = amber ? ClosedLayout.amberGlow : NSColor.white
        for eye in eyes {
            eye.fillColor = fill.cgColor
            eye.shadowColor = glow.cgColor
            eye.shadowOpacity = Float(amber ? ClosedLayout.amberGlowOpacity : OwlEyes.glowOpacity)
        }
    }

    private func blink(_ eye: CALayer, delay: Double) {
        let animation = CAKeyframeAnimation(keyPath: "transform.scale.y")
        animation.values = [1, 1, 0.1, 1]
        animation.keyTimes = [0, 0.92, 0.95, 1]
        animation.duration = OwlEyes.blinkInterval
        animation.repeatCount = .infinity
        animation.beginTime = CACurrentMediaTime() + delay
        eye.add(animation, forKey: "blink")
    }

    private func startBob() {
        let animation = CABasicAnimation(keyPath: "transform.translation.y")
        animation.fromValue = 0
        animation.toValue = MusicLayout.bobHeight
        animation.duration = MusicLayout.bobDuration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        container.add(animation, forKey: "bob")
    }
}
