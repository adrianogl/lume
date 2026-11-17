import SwiftUI

struct WeekBarsView: View {
    let bars: [WeekBar]

    private var maxValue: Double { max(bars.map(\.value).max() ?? 0, 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(bars) { bar in
                VStack(spacing: 5) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(bar.value > 0 ? Palette.redLight : Color.white.opacity(0.14))
                        .frame(height: max(4, 64 * bar.value / maxValue))
                    Text(bar.label)
                        .font(.system(size: 10, weight: bar.isToday ? .bold : .regular, design: .rounded))
                        .foregroundStyle(bar.isToday ? Color.white : Palette.textMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 92)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.rowFill))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Minutos de treino na semana")
    }
}
