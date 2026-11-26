import AppKit
import SwiftUI

struct MusicEarsView: NSViewRepresentable {
    let eyeCenterOffset: CGFloat
    let eyeSize: CGSize

    func makeNSView(context: Context) -> MusicEarsNSView {
        MusicEarsNSView()
    }

    func updateNSView(_ view: MusicEarsNSView, context: Context) {
        view.configure(eyeCenterOffset: eyeCenterOffset, eyeSize: eyeSize)
    }
}

final class MusicEarsNSView: NSView {
    private let eyes = CALayer()
    private let leftEye = CAShapeLayer()
    private let rightEye = CAShapeLayer()
    private var bars: [CALayer] = []
    private var eyeCenterOffset: CGFloat = 0
    private var eyeSize: CGSize = .zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        for eye in [leftEye, rightEye] {
            eye.fillColor = NSColor.white.cgColor
            eye.shadowColor = NSColor.white.cgColor
            eye.shadowOpacity = Float(OwlEyes.glowOpacity)
            eye.shadowRadius = OwlEyes.glowRadius
            eye.shadowOffset = .zero
            eyes.addSublayer(eye)
        }
        layer?.addSublayer(eyes)
        for index in 0..<MusicLayout.barCount {
            let bar = CALayer()
            bar.backgroundColor = NSColor(NotchRim.coral).cgColor
            bar.cornerRadius = MusicLayout.barWidth / 2
            layer?.addSublayer(bar)
            bars.append(bar)
            animate(bar, index: index)
        }
        bob()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(eyeCenterOffset: CGFloat, eyeSize: CGSize) {
        self.eyeCenterOffset = eyeCenterOffset
        self.eyeSize = eyeSize
        needsLayout = true
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        eyes.frame = bounds
        let midY = bounds.midY
        for (eye, sign) in [(leftEye, -1.0), (rightEye, 1.0)] {
            let center = CGPoint(x: bounds.midX + CGFloat(sign) * eyeCenterOffset, y: midY)
            let rect = CGRect(x: center.x - eyeSize.width / 2, y: center.y - eyeSize.height / 2, width: eyeSize.width, height: eyeSize.height)
            eye.frame = bounds
            eye.path = CGPath(ellipseIn: rect, transform: nil)
        }
        let barsWidth = CGFloat(MusicLayout.barCount) * MusicLayout.barWidth + CGFloat(MusicLayout.barCount - 1) * MusicLayout.barGap
        let startX = bounds.maxX - MusicLayout.barsTrailing - barsWidth
        for (index, bar) in bars.enumerated() {
            bar.bounds = CGRect(x: 0, y: 0, width: MusicLayout.barWidth, height: MusicLayout.barMaxHeight)
            bar.position = CGPoint(x: startX + CGFloat(index) * (MusicLayout.barWidth + MusicLayout.barGap) + MusicLayout.barWidth / 2, y: midY)
        }
        CATransaction.commit()
    }

    private func animate(_ bar: CALayer, index: Int) {
        let animation = CABasicAnimation(keyPath: "transform.scale.y")
        animation.fromValue = MusicLayout.barMinScale
        animation.toValue = 1
        animation.duration = MusicLayout.barDurations[index % MusicLayout.barDurations.count]
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.beginTime = CACurrentMediaTime() - Double(index) * 0.17
        bar.add(animation, forKey: "dance")
    }

    private func bob() {
        let animation = CABasicAnimation(keyPath: "transform.translation.y")
        animation.fromValue = 0
        animation.toValue = MusicLayout.bobHeight
        animation.duration = MusicLayout.bobDuration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        eyes.add(animation, forKey: "bob")
    }
}
