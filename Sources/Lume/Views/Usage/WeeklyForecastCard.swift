import SwiftUI

struct WeeklyForecastCard: View {
    @ObservedObject var store: UsageStore
    let colors: [String: Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Previsão semanal")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("no ritmo desta semana")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textMuted)
                Spacer()
            }
            ForEach(store.accounts) { account in
                ForecastRow(
                    name: account.name,
                    color: colors[account.name] ?? .gray,
                    forecast: store.weeklyForecast(account: account.name)
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.rowFill))
    }
}

private struct ForecastRow: View {
    let name: String
    let color: Color
    let forecast: WeeklyForecast?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(name).font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .frame(width: 78, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                ForecastBar(used: forecast?.usedPercent ?? 0, projected: forecast?.projectedPercent ?? 0, hitsLimit: hitsLimit)
                HStack(spacing: 8) {
                    outcomeText
                    Spacer(minLength: 6)
                    if let forecast {
                        Text(detail(forecast))
                            .foregroundStyle(Palette.textMuted)
                            .monospacedDigit()
                    }
                }
                .font(.system(size: 11))
                .lineLimit(1)
            }
        }
    }

    private var hitsLimit: Bool {
        switch forecast?.outcome {
        case .atLimit, .hits: return true
        default: return false
        }
    }

    @ViewBuilder
    private var outcomeText: some View {
        switch forecast?.outcome {
        case .atLimit:
            Text("no limite").fontWeight(.semibold).foregroundStyle(Palette.redLight)
        case .hits(let date):
            Text("chega ao limite \(Format.forecast(date))").fontWeight(.semibold).foregroundStyle(Palette.redLight)
        case .closes(let percent):
            (Text("não chega").fontWeight(.semibold).foregroundColor(Palette.live)
                + Text(" · fecha em ~\(Int(percent.rounded()))%").foregroundColor(Palette.textMuted))
        case nil:
            Text("sem dados suficientes").foregroundStyle(Palette.textMuted)
        }
    }

    private func detail(_ forecast: WeeklyForecast) -> String {
        Format.percentRate(forecast.ratePerDay) + " · reset " + Format.reset(forecast.resetsAt)
    }
}

private struct ForecastBar: View {
    let used: Double
    let projected: Double
    let hitsLimit: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let usedWidth = width * min(used, 100) / 100
            let projectedWidth = width * min(max(projected, used), 100) / 100
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Path { path in
                    path.move(to: CGPoint(x: usedWidth, y: 3))
                    path.addLine(to: CGPoint(x: projectedWidth, y: 3))
                }
                .stroke(
                    (hitsLimit ? Palette.redLight : Color.white).opacity(0.4),
                    style: StrokeStyle(lineWidth: 6, dash: [3, 2])
                )
                Capsule()
                    .fill(hitsLimit ? Palette.redLight : Color.white.opacity(0.9))
                    .frame(width: usedWidth)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Palette.redLight)
                    .frame(width: 2, height: 12)
                    .position(x: width - 1, y: 3)
            }
        }
        .frame(height: 6)
    }
}
