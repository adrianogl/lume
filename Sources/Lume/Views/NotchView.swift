import SwiftUI

struct NotchView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var usage: UsageStore
    @ObservedObject var prs: PullRequestStore

    var body: some View {
        VStack(spacing: 0) {
            island
            Spacer(minLength: 0)
        }
        .frame(width: Metrics.windowSize.width, height: Metrics.windowSize.height, alignment: .top)
    }

    private var radius: CGFloat {
        if model.isOpen { return Metrics.openCornerRadius }
        return model.alert == nil ? Metrics.closedCornerRadius : AlertConfig.cornerRadius
    }

    private var island: some View {
        let size = model.currentSize
        let shape = NotchShape(
            topRadius: model.isOpen ? Metrics.openTopFlare : Metrics.closedTopFlare,
            bottomRadius: radius
        )

        return VStack(spacing: 0) {
            EarsView(model: model)
            if model.isOpen {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 16) {
                        SidebarView(model: model)
                        VStack(alignment: .leading, spacing: 10) {
                            if let exchange = model.exchange {
                                ExchangeView(exchange: exchange)
                            }
                            if model.activeID == PRConfig.categoryID {
                                PullRequestView(store: prs)
                            } else if model.activeID == UsageConfig.categoryID {
                                UsageView(store: usage)
                            } else if let active = model.active {
                                CategoryContentView(category: active)
                            }
                        }
                        .padding(.bottom, AlertHistoryConfig.bellReservedHeight)
                    }
                }
                .padding(.horizontal, Metrics.openContentPadding)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .frame(maxHeight: .infinity, alignment: .top)
                .overlay(alignment: .bottomTrailing) {
                    AlertHistoryCorner(model: model)
                        .padding(.trailing, Metrics.openContentPadding)
                        .padding(.bottom, 16)
                }
                .transition(.opacity.animation(.easeOut(duration: 0.2).delay(0.12)))
            } else if let alert = model.alert {
                AlertBanner(alert: alert) { model.dismissAlert() }
                    .transition(.opacity.combined(with: .offset(y: -6)).animation(.easeOut(duration: 0.25).delay(0.12)))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(IslandBackground(isOpen: model.isOpen, glow: model.glow))
        .clipShape(shape)
        .shadow(color: .black.opacity(model.isOpen ? 0.45 : 0), radius: 24, y: 12)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .onHover { model.hoverChanged($0) }
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): model.moveGlow(to: point)
            case .ended: model.resetGlow()
            }
        }
    }
}

struct IslandBackground: View {
    let isOpen: Bool
    let glow: UnitPoint

    var body: some View {
        ZStack {
            if isOpen {
                VisualEffectView()
                Palette.panelTint.opacity(0.8)
                GeometryReader { geo in
                    Circle()
                        .fill(RadialGradient(
                            colors: [Palette.red.opacity(0.62), Palette.red.opacity(0.14), Palette.red.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: Metrics.glowDiameter / 2
                        ))
                        .frame(width: Metrics.glowDiameter, height: Metrics.glowDiameter)
                        .position(x: glow.x * geo.size.width, y: glow.y * geo.size.height)
                }
            } else {
                Color.black
            }
        }
    }
}
