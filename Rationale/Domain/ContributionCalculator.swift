import Foundation

enum ContributionSuggestionSource: Equatable, Sendable {
    case fixed
    case withinTolerance
    case balanced
}

struct ContributionSuggestion: Equatable, Sendable {
    var source: ContributionSuggestionSource
    var weights: AllocationWeights
    var amountsKrw: [AssetCategory: Int]

    var totalKrw: Int { amountsKrw.values.reduce(0, +) }
}

enum ContributionCalculator {
    static func suggest(
        contributionKrw: Int,
        target: AllocationWeights,
        toleranceBps: Int,
        current: PortfolioHoldings,
        balanceAssistEnabled: Bool
    ) -> ContributionSuggestion? {
        guard contributionKrw >= 0, target.isValid, toleranceBps >= 0 else { return nil }
        let fixed = fixedSuggestion(contributionKrw: contributionKrw, target: target)
        guard balanceAssistEnabled, current.totalKrw > 0, contributionKrw > 0 else { return fixed }

        let outsideTolerance = AssetCategory.allCases.contains { category in
            let currentBps = Double(current[category]) / Double(current.totalKrw) * 10_000
            return abs(currentBps - Double(target[category])) > Double(toleranceBps)
        }
        guard outsideTolerance else {
            return ContributionSuggestion(source: .withinTolerance, weights: fixed.weights, amountsKrw: fixed.amountsKrw)
        }

        let postContributionTotal = current.totalKrw + contributionKrw
        let gaps = AssetCategory.allCases.map { category in
            max(0, Double(postContributionTotal) * Double(target[category]) / 10_000 - Double(current[category]))
        }
        let gapTotal = gaps.reduce(0, +)
        guard gapTotal > 0 else { return fixed }

        let gapBudget = min(Double(contributionKrw), gapTotal)
        var rawAmounts = gaps.map { $0 / gapTotal * gapBudget }
        let remainder = Double(contributionKrw) - gapBudget
        if remainder > 0 {
            for index in rawAmounts.indices {
                rawAmounts[index] += remainder * Double(target[AssetCategory.allCases[index]]) / 10_000
            }
        }

        let amounts = allocateExactly(total: contributionKrw, rawWeights: rawAmounts)
        let suggestedBps = allocateExactly(total: 10_000, rawWeights: amounts.map(Double.init))
        let weights = AllocationWeights(cash: suggestedBps[0], stocks: suggestedBps[1], bonds: suggestedBps[2])
        return ContributionSuggestion(source: .balanced, weights: weights, amountsKrw: dictionary(amounts))
    }

    static func allocateStockBudget(totalKrw: Int, targets: [StockAllocationTarget]) -> [UUID: Int]? {
        guard totalKrw >= 0, !targets.isEmpty, targets.reduce(0, { $0 + $1.targetBps }) == 10_000 else { return nil }
        let amounts = allocateExactly(total: totalKrw, integerWeights: targets.map(\.targetBps))
        return Dictionary(uniqueKeysWithValues: zip(targets.map(\.id), amounts))
    }

    static func allocateExactly(total: Int, integerWeights: [Int]) -> [Int] {
        allocateExactly(total: total, rawWeights: integerWeights.map(Double.init))
    }

    private static func fixedSuggestion(contributionKrw: Int, target: AllocationWeights) -> ContributionSuggestion {
        let amounts = allocateExactly(total: contributionKrw, integerWeights: AssetCategory.allCases.map { target[$0] })
        return ContributionSuggestion(source: .fixed, weights: target, amountsKrw: dictionary(amounts))
    }

    private static func allocateExactly(total: Int, rawWeights: [Double]) -> [Int] {
        guard total > 0, !rawWeights.isEmpty else { return Array(repeating: 0, count: rawWeights.count) }
        let safeWeights = rawWeights.map { $0.isFinite && $0 > 0 ? $0 : 0 }
        let weightTotal = safeWeights.reduce(0, +)
        guard weightTotal > 0 else { return Array(repeating: 0, count: rawWeights.count) }

        let exact = safeWeights.map { Double(total) * $0 / weightTotal }
        var allocated = exact.map { Int($0.rounded(.down)) }
        var remainder = total - allocated.reduce(0, +)
        let ranked = exact.indices.sorted {
            let left = exact[$0] - Double(allocated[$0])
            let right = exact[$1] - Double(allocated[$1])
            return left == right ? $0 < $1 : left > right
        }
        var cursor = 0
        while remainder > 0 {
            allocated[ranked[cursor % ranked.count]] += 1
            remainder -= 1
            cursor += 1
        }
        return allocated
    }

    private static func dictionary(_ amounts: [Int]) -> [AssetCategory: Int] {
        Dictionary(uniqueKeysWithValues: zip(AssetCategory.allCases, amounts))
    }
}

