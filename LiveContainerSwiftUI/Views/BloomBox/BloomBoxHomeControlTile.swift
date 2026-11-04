import SwiftUI

/// Home settings tile that does not depend on guest app or signing models.
struct BloomBoxHomeControlTile: View {
    let title: String
    let detail: String
    let symbol: String
    let wide: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            Spacer(minLength: 6)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: wide ? 124 : 128)
        .liveBoardGlass(radius: 28, interactive: false)
        .contentShape(RoundedRectangle(cornerRadius: 28))
    }
}
