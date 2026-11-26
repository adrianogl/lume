import AppKit
import SwiftUI

struct BarsLayerView: NSViewRepresentable {
    func makeNSView(context: Context) -> BarsLayerNSView {
        BarsLayerNSView()
    }

    func updateNSView(_ view: BarsLayerNSView, context: Context) {}
}

final class BarsLayerNSView: NSView {
    private var bars: [CALayer] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        for index in 0..<MusicLayout.barCount {
            let bar = CALayer()
            bar.backgroundColor = NSColor(NotchRim.coral).cgColor
            bar.cornerRadius = MusicLayout.barWidth / 2
            layer?.addSublayer(bar)
            bars.append(bar)
            animate(bar, index: index)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, bar) in bars.enumerated() {
            bar.bounds = CGRect(x: 0, y: 0, width: MusicLayout.barWidth, height: MusicLayout.barMaxHeight)
            bar.position = CGPoint(x: CGFloat(index) * (MusicLayout.barWidth + MusicLayout.barGap) + MusicLayout.barWidth / 2, y: bounds.midY)
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

    static var width: CGFloat {
        CGFloat(MusicLayout.barCount) * MusicLayout.barWidth + CGFloat(MusicLayout.barCount - 1) * MusicLayout.barGap
    }
}
