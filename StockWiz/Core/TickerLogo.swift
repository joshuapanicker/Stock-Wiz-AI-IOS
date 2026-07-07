import SwiftUI

// MARK: - TickerLogo
// Loads a company logo from Parqet's free public logo API.
// Falls back to a colored letter avatar when the logo is unavailable.
// Usage: TickerLogo(symbol: "AAPL", size: 40)

struct TickerLogo: View {
    let symbol: String
    let size: CGFloat

    // Consistent color per symbol using the DS chart palette
    private var letterColor: Color {
        let palette: [Color] = [
            DS.Color.accent, DS.Color.violet, DS.Color.sky,
            DS.Color.amber, DS.Color.mint, DS.Color.rose, DS.Color.gold
        ]
        let index = symbol.unicodeScalars.reduce(0) { $0 + Int($1.value) } % palette.count
        return palette[index]
    }

    var body: some View {
        AsyncImage(
            url: URL(string: "https://assets.parqet.com/logos/symbol/\(symbol.uppercased())?format=jpg")
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
            default:
                // Letter avatar fallback — always renders, even during loading
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.28)
                        .fill(letterColor.opacity(0.12))
                    RoundedRectangle(cornerRadius: size * 0.28)
                        .stroke(letterColor.opacity(0.22))
                    Text(String(symbol.prefix(2).uppercased()))
                        .font(.system(size: size * 0.34, weight: .bold, design: .monospaced))
                        .foregroundStyle(letterColor)
                }
                .frame(width: size, height: size)
            }
        }
        // Explicit frame prevents AsyncImage from collapsing in LazyVStack
        .frame(width: size, height: size)
        .clipped()
    }
}
