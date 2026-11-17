import SwiftUI

struct ExchangeView: View {
    let exchange: VoiceExchange

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "waveform")
                    .foregroundStyle(Palette.redLight)
                Text(exchange.heard.isEmpty ? "Ouvindo…" : "“\(exchange.heard)”")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(exchange.heard.isEmpty ? Palette.textMuted : Color.white)
                    .lineLimit(2)
            }
            if let reply = exchange.reply {
                Text(reply)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textMuted)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.1)))
    }
}
