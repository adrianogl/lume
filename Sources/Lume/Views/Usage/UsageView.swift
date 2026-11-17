import Charts
import ServiceManagement
import SwiftUI

struct UsageView: View {
    @ObservedObject var store: UsageStore
    @State private var filter = UsageConfig.allAccountsLabel
    @State private var period: Period = .week
    @State private var hoverX: Date?
    @State private var pinnedX: Date?
    @AppStorage(UsageConfig.Keys.excludeWeekends) private var excludeWeekends = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var accountNames: [String] { store.accounts.map(\.name) }
    private var selectedNames: [String] { filter == UsageConfig.allAccountsLabel ? accountNames : [filter] }
    private var colorByAccount: [String: Color] {
        Dictionary(uniqueKeysWithValues: zip(accountNames, UsageConfig.accountColors))
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 10) {
                header
                HStack(spacing: 8) {
                    ForEach(store.accounts) { account in
                        AccountTile(
                            name: account.name,
                            state: store.states[account.name] ?? AccountState(),
                            todayTokens: store.tokens(account: account.name, onDay: Date())
                        )
                    }
                }
                WeeklyForecastCard(store: store, colors: colorByAccount)
                chartCard
                consumptionCard
                settings
            }
            .padding(.bottom, 6)
        }
        .scrollIndicators(.never)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Claude")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Spacer()
            Text(store.isScanningLogs ? "lendo logs…" : Format.relative(store.lastRefresh))
                .font(.system(size: 11))
                .foregroundStyle(Palette.textMuted)
            Button {
                store.refreshAll()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Palette.rowFill))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(store.isRefreshing ? 0.3 : 0.85))
            .disabled(store.isRefreshing)
            .help("Atualizar agora")
        }
    }

    private var chartPoints: [ChartPoint] {
        let calendar = Calendar.current
        if period == .today {
            let hour = calendar.component(.hour, from: Date())
            return selectedNames.flatMap { name in
                (0...hour).map { h in
                    ChartPoint(account: name, x: calendar.date(bySettingHour: h, minute: 0, second: 0, of: Date())!,
                               tokens: store.states[name]?.hourlyToday[h] ?? 0)
                }
            }
        }
        let today = calendar.startOfDay(for: Date())
        let days = (0..<period.dayCount).reversed()
            .map { calendar.date(byAdding: .day, value: -$0, to: today)! }
            .filter { !excludeWeekends || !calendar.isDateInWeekend($0) }
        return selectedNames.flatMap { name in
            days.map { ChartPoint(account: name, x: $0, tokens: store.tokens(account: name, onDay: $0)) }
        }
    }

    private var chartCard: some View {
        let points = chartPoints
        let total = points.reduce(0) { $0 + $1.tokens }
        let totals = Dictionary(grouping: points, by: \.x)
            .map { ChartPoint(account: "Total", x: $0.key, tokens: $0.value.reduce(0) { $0 + $1.tokens }) }
            .sorted { $0.x < $1.x }
        return LumeCard {
            HStack(alignment: .firstTextBaseline) {
                Text("Tokens")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                Text(Format.tokens(total))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(period == .today ? "hoje" : "em \(period.label)")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textMuted)
            }
            HStack(spacing: 6) {
                ChipGroup(options: Period.allCases, selection: $period) { $0.label }
                Spacer(minLength: 6)
                ChipGroup(options: [UsageConfig.allAccountsLabel] + accountNames, selection: $filter) { $0 }
            }
            Chart {
                ForEach(totals) { point in
                    AreaMark(x: .value("Data", point.x), y: .value("Tokens", point.tokens))
                        .foregroundStyle(
                            LinearGradient(colors: [Palette.red.opacity(0.35), Palette.red.opacity(0)], startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.monotone)
                }
                ForEach(points) { point in
                    LineMark(x: .value("Data", point.x), y: .value("Tokens", point.tokens))
                        .foregroundStyle(by: .value("Conta", point.account))
                        .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round))
                        .interpolationMethod(.monotone)
                }
                if !totals.isEmpty {
                    let average = total / totals.count
                    RuleMark(y: .value("Média", average))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("média " + Format.tokens(average))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(Palette.textMuted)
                        }
                }
                if let selected = selectedPoint(in: points) {
                    RuleMark(x: .value("Data", selected))
                        .foregroundStyle(Color.white.opacity(0.35))
                    ForEach(points.filter { $0.x == selected }) { point in
                        PointMark(x: .value("Data", point.x), y: .value("Tokens", point.tokens))
                            .foregroundStyle(by: .value("Conta", point.account))
                            .symbolSize(28)
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    let originX = proxy.plotFrame.map { geo[$0].origin.x } ?? 0
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                hoverX = proxy.value(atX: location.x - originX, as: Date.self)
                            case .ended:
                                hoverX = nil
                            }
                        }
                        .onTapGesture { location in
                            pinnedX = proxy.value(atX: location.x - originX, as: Date.self)
                        }
                }
            }
            .chartForegroundStyleScale(domain: accountNames, range: UsageConfig.accountColors)
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.07))
                    AxisValueLabel {
                        if let tokens = value.as(Int.self) {
                            Text(Format.tokens(tokens)).foregroundStyle(Palette.textMuted)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(period == .today ? "\(Calendar.current.component(.hour, from: date))h" : Format.dayLabel(date))
                                .foregroundStyle(Palette.textMuted)
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .frame(height: 120)
            .onChange(of: period) { _, _ in pinnedX = nil }
            .onChange(of: filter) { _, _ in pinnedX = nil }

            HStack(spacing: 12) {
                ForEach(selectedNames, id: \.self) { name in
                    HStack(spacing: 5) {
                        Circle().fill(colorByAccount[name] ?? .gray).frame(width: 6, height: 6)
                        Text(name)
                    }
                }
                Spacer()
                if period != .today {
                    Toggle("Só dias úteis", isOn: $excludeWeekends)
                        .toggleStyle(.checkbox)
                        .onChange(of: excludeWeekends) { _, _ in pinnedX = nil }
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(Palette.textMuted)

            selectionDetail(points)
        }
    }

    private func selectedPoint(in points: [ChartPoint]) -> Date? {
        guard let target = hoverX ?? pinnedX else { return nil }
        let xs = Set(points.map(\.x))
        return xs.min { abs($0.timeIntervalSince(target)) < abs($1.timeIntervalSince(target)) }
    }

    @ViewBuilder
    private func selectionDetail(_ points: [ChartPoint]) -> some View {
        if let selected = selectedPoint(in: points) {
            let values = points.filter { $0.x == selected }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(period == .today ? Format.hourLabel(selected) : Format.fullDayLabel(selected))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Spacer()
                    if values.count > 1 {
                        Text("total " + Format.tokens(values.reduce(0) { $0 + $1.tokens }))
                            .foregroundStyle(Palette.textMuted)
                    }
                }
                ForEach(values) { point in
                    HStack(spacing: 6) {
                        Circle().fill(colorByAccount[point.account] ?? .gray).frame(width: 6, height: 6)
                        Text(point.account)
                        Spacer()
                        Text(Format.tokens(point.tokens)).monospacedDigit()
                    }
                }
            }
            .font(.system(size: 11))
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.06)))
        }
    }

    private var consumptionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Consumo")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                if excludeWeekends {
                    Text("só dias úteis")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .padding(.horizontal, 2)
            ForEach(selectedNames, id: \.self) { name in
                let month = store.tokens(account: name, lastDays: 30, excludeWeekends: excludeWeekends)
                let monthDays = max(store.days(last: 30, excludeWeekends: excludeWeekends).count, 1)
                let weeks = store.weeksAtLimit(account: name)
                HStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Circle().fill(colorByAccount[name] ?? .gray).frame(width: 6, height: 6)
                        Text(name).font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .frame(width: 78, alignment: .leading)
                    Metric(label: "semana", value: Format.tokens(store.tokens(account: name, lastDays: 7, excludeWeekends: excludeWeekends)))
                    Metric(label: "30 dias", value: Format.tokens(month))
                    Metric(label: "média/dia", value: Format.tokens(month / monthDays))
                    Metric(label: "sem. no limite", value: "\(weeks)", highlight: weeks > 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.rowFill))
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Abrir no login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Text("· aviso acima de \(Int(store.alertThreshold))%")
                    .foregroundStyle(Palette.textMuted)
                Spacer()
                Button("Sair do Lume") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.redLight)
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 2)
        .padding(.top, 4)
    }
}

private struct AccountTile: View {
    let name: String
    let state: AccountState
    let todayTokens: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(Format.plan(state.snapshot?.plan))
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textMuted)
                    .lineLimit(1)
            }

            if let error = state.error, state.snapshot == nil {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            } else {
                LimitLine(label: "5h", window: state.snapshot?.fiveHour, isPrimary: true)
                LimitLine(label: "semana", window: state.snapshot?.sevenDay, isPrimary: false)
            }

            Text("hoje " + (state.logsLoaded ? Format.tokens(todayTokens) : "…"))
                .font(.system(size: 10))
                .foregroundStyle(Palette.textMuted)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.rowFill))
    }
}

private struct LimitLine: View {
    let label: String
    let window: LimitWindow?
    let isPrimary: Bool

    private var value: Double { window?.utilization ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(window == nil ? "—" : "\(Int(value.rounded()))%")
                    .font(.system(size: isPrimary ? 20 : 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LimitColors.level(value))
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textMuted)
                Spacer(minLength: 0)
                if let reset = window?.resetsAt {
                    Text(Format.reset(reset))
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.textMuted)
                        .lineLimit(1)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(LimitColors.level(value))
                        .frame(width: geo.size.width * min(value, 100) / 100)
                }
            }
            .frame(height: isPrimary ? 4 : 3)
        }
    }
}

private struct Metric: View {
    let label: String
    let value: String
    var highlight = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(highlight ? Palette.redLight : Color.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Palette.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum LimitColors {
    static func level(_ value: Double) -> Color {
        if value >= UsageConfig.criticalLevel { return Palette.redLight }
        if value >= UsageConfig.warningLevel { return Color(red: 1, green: 170 / 255, blue: 150 / 255) }
        return Color.white.opacity(0.9)
    }
}

private struct LumeCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.rowFill))
    }
}

private struct ChipGroup<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(label(option))
                        .font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .rounded))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(isSelected ? Color.white.opacity(0.16) : .clear))
                        .foregroundStyle(isSelected ? Color.white : Palette.textMuted)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
