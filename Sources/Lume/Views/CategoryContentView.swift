import SwiftUI

struct CategoryContentView: View {
    let category: LumeCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(category.title)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Spacer()
                Text(category.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textMuted)
            }

            if !category.tiles.isEmpty {
                HStack(spacing: 8) {
                    ForEach(category.tiles) { TileView(tile: $0) }
                }
            }

            ForEach(category.rows) { RowView(row: $0) }

            if !category.bars.isEmpty {
                WeekBarsView(bars: category.bars)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TileView: View {
    let tile: StatTile

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tile.label)
                .font(.system(size: 11))
                .foregroundStyle(Palette.textMuted)
            Text(tile.value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.color(for: tile.trend))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.rowFill))
    }
}

private struct RowView: View {
    let row: ContentRow

    var body: some View {
        HStack(spacing: 10) {
            if let checked = row.checked {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(checked ? Palette.redLight : Color.white.opacity(0.5))
            }
            if let time = row.time {
                Text(time)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Palette.redLight)
                    .frame(width: 40, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                if let detail = row.detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textMuted)
                }
            }
            Spacer(minLength: 8)
            if let trailing = row.trailing {
                Text(trailing)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Palette.color(for: row.trend))
            }
            if let url = row.actionURL {
                JoinButton(url: url, title: row.actionTitle ?? "Entrar", isLarge: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.rowFill))
    }
}
