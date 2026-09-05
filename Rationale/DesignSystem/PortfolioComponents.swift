import SwiftUI

struct PortfolioMetricCard: View {
    let label: String
    let value: String
    let help: String
    var tone: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(help)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .rationaleCard(padding: 14)
    }
}

struct PortfolioSectionHeader: View {
    let eyebrow: String
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(RationaleTheme.accent)
            Text(title)
                .font(.title2.weight(.bold))
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PortfolioDonut: View {
    let weights: AllocationWeights
    let centerValue: String
    let centerLabel: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: 28)
            if weights.total > 0 {
                ForEach(Array(AssetCategory.allCases.enumerated()), id: \.element.id) { index, category in
                    Circle()
                        .trim(from: start(for: index), to: end(for: index))
                        .stroke(category.color, style: StrokeStyle(lineWidth: 28, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
            }
            VStack(spacing: 3) {
                Text(centerValue)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(centerLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .frame(width: 170, height: 170)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func start(for index: Int) -> Double {
        let preceding = AssetCategory.allCases.prefix(index).reduce(0) { $0 + weights[$1] }
        return Double(preceding) / Double(max(weights.total, 1))
    }

    private func end(for index: Int) -> Double {
        let including = AssetCategory.allCases.prefix(index + 1).reduce(0) { $0 + weights[$1] }
        return Double(including) / Double(max(weights.total, 1))
    }

    private var accessibilityLabel: String {
        let detail = AssetCategory.allCases.map { "\($0.title) \(PortfolioFormat.percent(weights[$0]))" }.joined(separator: ", ")
        return "자산 배분. \(detail)"
    }
}

struct AllocationRangeBar: View {
    let currentBps: Int?
    let targetBps: Int
    let toleranceBps: Int
    var color: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let lower = max(0, targetBps - toleranceBps)
            let upper = min(10_000, targetBps + toleranceBps)
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(RationaleTheme.accent.opacity(0.18))
                    .frame(width: width * CGFloat(upper - lower) / 10_000)
                    .offset(x: width * CGFloat(lower) / 10_000)
                if let currentBps {
                    Capsule()
                        .fill(color)
                        .frame(width: max(4, width * CGFloat(min(max(currentBps, 0), 10_000)) / 10_000))
                }
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 2, height: 16)
                    .offset(x: width * CGFloat(targetBps) / 10_000 - 1)
            }
        }
        .frame(height: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("현재 \(currentBps.map(PortfolioFormat.percent) ?? "미입력"), 목표 \(PortfolioFormat.percent(targetBps)), 허용 오차 \(PortfolioFormat.percent(toleranceBps))")
    }
}

struct CategoryLegend: View {
    let category: AssetCategory
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(category.color)
                .frame(width: 30, height: 30)
                .background(category.color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title).font(.subheadline.weight(.semibold))
                if let subtitle {
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct StatusPill: View {
    let text: String
    var color: Color = RationaleTheme.accent

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }
}

