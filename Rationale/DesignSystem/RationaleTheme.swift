import SwiftUI

enum RationaleTheme {
    static let accent = Color(red: 0.24, green: 0.76, blue: 0.47)
    static let cash = Color(red: 0.79, green: 0.58, blue: 0.25)
    static let stocks = Color(red: 0.14, green: 0.53, blue: 0.41)
    static let bonds = Color(red: 0.36, green: 0.52, blue: 0.70)
    static let warning = Color.orange
}

extension AssetCategory {
    var color: Color {
        switch self {
        case .cash: RationaleTheme.cash
        case .stocks: RationaleTheme.stocks
        case .bonds: RationaleTheme.bonds
        }
    }
}

extension View {
    func rationaleCard(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color(.separator).opacity(0.35), lineWidth: 0.5)
            }
    }
}

enum PortfolioFormat {
    static func krw(_ value: Int) -> String {
        value.formatted(.currency(code: "KRW").precision(.fractionLength(0)))
    }

    static func percent(_ bps: Int) -> String {
        (Double(bps) / 100).formatted(.number.precision(.fractionLength(0...2))) + "%"
    }

    static func signedPercentagePoints(_ bps: Int) -> String {
        let prefix = bps > 0 ? "+" : ""
        return prefix + (Double(bps) / 100).formatted(.number.precision(.fractionLength(0...2))) + "%p"
    }
}

