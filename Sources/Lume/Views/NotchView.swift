import SwiftUI

struct NotchView: View {
    @ObservedObject var model: NotchModel
    let config: ConfigStore
    let week: WeekEventStore
    let music: MusicController
    let claude: ClaudeCodeMonitor
    let pullRequests: PullRequestMonitor
    let usage: ClaudeUsageMonitor
    let commands: CommandMonitor
    let canvasSize: CGSize
    let eyeCenterOffset: CGFloat
    @State private var isBlinking = false

    private var eyeSize: CGSize { OwlEyes.size(forNotchHeight: model.restingSize.height) }

    var body: some View {
        let flare = NotchCurve.flare(forHeight: model.size.height)
        let radius = NotchCurve.cornerRadius(forHeight: model.size.height)
        ZStack(alignment: .top) {
            RimGradientView(colors: model.alert?.isFailure == true ? CommandLayout.failedRim : NotchRim.colors)
                .frame(width: canvasSize.width, height: canvasSize.height)
                .mask(alignment: .top) {
                    NotchShape(topRadius: flare, bottomRadius: radius)
                        .fill(LinearGradient(
                            stops: [
                                .init(color: .clear, location: NotchRim.fadeStart),
                                .init(color: .black, location: NotchRim.fadeEnd)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: model.size.width + flare * 2, height: model.size.height)
                }

            NotchShape(topRadius: flare, bottomRadius: max(radius - NotchRim.bottomThickness, 0))
                .fill(.black)
                .frame(
                    width: model.size.width + flare * 2 - NotchRim.sideThickness * 2,
                    height: model.size.height - NotchRim.bottomThickness
                )

            ZStack(alignment: .topLeading) {
                if model.isOpen {
                    OpenNotchContent(model: model, config: config, week: week, music: music, claude: claude, pullRequests: pullRequests, usage: usage, commands: commands)
                        .transition(OpenLayout.contentTransition)

                    if model.currentPage == .clock {
                        OwlMascot(width: OpenLayout.mascotWidth, isBlinking: isBlinking)
                            .offset(x: OpenLayout.mascotOrigin.x + (model.pages.count > 1 ? OpenLayout.arrowInset : 0), y: OpenLayout.mascotOrigin.y)
                            .transition(.scale(scale: OpenLayout.mascotAppearScale, anchor: .topLeading).combined(with: .opacity))
                    }
                } else if let alert = model.alert {
                    AlertPillView(alert: alert, isBlinking: isBlinking, dismiss: model.dismissAlert, onContentHeight: model.fitAlert)
                        .padding(.top, model.contentTopInset)
                        .frame(width: model.size.width, height: model.size.height)
                        .transition(OpenLayout.contentTransition)
                } else {
                    ClosedStatusView(
                        meeting: model.meeting,
                        isMusicPlaying: model.isMusicActive,
                        isClaudeWaiting: model.isClaudeWaiting,
                        pullRequestCount: model.pullRequestCount,
                        usagePercent: model.usagePercent,
                        runningCommand: model.runningCommand,
                        eyeSize: eyeSize,
                        eyeCenterOffset: eyeCenterOffset
                    )
                    .frame(width: model.size.width, height: model.restingSize.height)
                    .transition(.opacity)
                }
            }
            .frame(width: model.size.width, height: model.size.height, alignment: .topLeading)
            .clipped()
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .top)
        .foregroundStyle(.white)
        .task { await blinkForever() }
    }

    private func blinkForever() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(OwlEyes.blinkInterval))
            withAnimation(.easeInOut(duration: OwlEyes.blinkDuration)) { isBlinking = true }
            try? await Task.sleep(for: .seconds(OwlEyes.blinkDuration * 1.5))
            withAnimation(.easeInOut(duration: OwlEyes.blinkDuration)) { isBlinking = false }
        }
    }
}
