import SwiftUI

struct OpenNotchContent: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var config: ConfigStore
    @ObservedObject var week: WeekEventStore

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch model.currentPage {
                case .clock:
                    ClockPageView()
                case .week:
                    WeekPageView(store: week, showWeekend: config.config.modules.week.showWeekend)
                case nil:
                    Text(OpenLayout.noModules)
                        .font(.system(size: WeekLayout.rowSize))
                        .opacity(WeekLayout.secondaryOpacity)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if model.pages.count > 1 {
                HStack(spacing: OpenLayout.dotSpacing - OpenLayout.dotHitPadding) {
                    ForEach(model.pages.indices, id: \.self) { index in
                        let isActive = index == model.pageIndex
                        Button { model.showPage(index) } label: {
                            Capsule()
                                .fill(.white.opacity(isActive ? 1 : OpenLayout.inactiveDotOpacity))
                                .frame(width: isActive ? OpenLayout.activeDotWidth : OpenLayout.dotSize, height: OpenLayout.dotSize)
                                .padding(.vertical, OpenLayout.dotHitPadding)
                                .padding(.horizontal, OpenLayout.dotHitPadding / 2)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(model.pages[index].title)
                    }
                }
                .padding(.bottom, OpenLayout.dotsBottom - OpenLayout.dotHitPadding)
            }

            HStack {
                Spacer()
                Button(action: model.openSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: SettingsLayout.gearSize))
                        .opacity(OpenLayout.inactiveDotOpacity)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(SettingsText.openSettings)
            }
            .padding(.trailing, SettingsLayout.gearInset - 6)
            .padding(.bottom, OpenLayout.dotsBottom - 6)
        }
    }
}
