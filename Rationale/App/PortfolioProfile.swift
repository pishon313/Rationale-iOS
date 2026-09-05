import Foundation
import SwiftData

enum AssetCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case cash
    case stocks
    case bonds

    var id: Self { self }

    var title: String {
        switch self {
        case .cash: "현금성 자산"
        case .stocks: "주식"
        case .bonds: "채권"
        }
    }

    var shortTitle: String {
        switch self {
        case .cash: "현금"
        case .stocks: "주식"
        case .bonds: "채권"
        }
    }

    var symbol: String {
        switch self {
        case .cash: "banknote"
        case .stocks: "chart.line.uptrend.xyaxis"
        case .bonds: "building.columns"
        }
    }
}

struct AllocationWeights: Equatable, Sendable {
    var cash: Int
    var stocks: Int
    var bonds: Int

    var total: Int { cash + stocks + bonds }
    var isValid: Bool { total == 10_000 && [cash, stocks, bonds].allSatisfy { (0...10_000).contains($0) } }

    subscript(category: AssetCategory) -> Int {
        get {
            switch category {
            case .cash: cash
            case .stocks: stocks
            case .bonds: bonds
            }
        }
        set {
            switch category {
            case .cash: cash = newValue
            case .stocks: stocks = newValue
            case .bonds: bonds = newValue
            }
        }
    }
}

struct PortfolioHoldings: Equatable, Sendable {
    var cashKrw: Int
    var stocksKrw: Int
    var bondsKrw: Int

    var totalKrw: Int { cashKrw + stocksKrw + bondsKrw }

    subscript(category: AssetCategory) -> Int {
        switch category {
        case .cash: cashKrw
        case .stocks: stocksKrw
        case .bonds: bondsKrw
        }
    }
}

struct StockAllocationTarget: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var ticker: String
    var name: String
    var targetBps: Int
    var currentValueKrw: Int

    init(id: UUID = UUID(), ticker: String, name: String, targetBps: Int, currentValueKrw: Int = 0) {
        self.id = id
        self.ticker = ticker
        self.name = name
        self.targetBps = targetBps
        self.currentValueKrw = currentValueKrw
    }
}

@Model
final class PortfolioProfile {
    var name: String
    var monthlyContributionKrw: Int
    var cashTargetBps: Int
    var stockTargetBps: Int
    var bondTargetBps: Int
    var toleranceBps: Int
    var balanceAssistEnabled: Bool
    var currentCashKrw: Int
    var currentStocksKrw: Int
    var currentBondsKrw: Int
    var stockTargetsData: Data
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String = "내 포트폴리오",
        monthlyContributionKrw: Int = 1_000_000,
        cashTargetBps: Int = 3_000,
        stockTargetBps: Int = 6_000,
        bondTargetBps: Int = 1_000,
        toleranceBps: Int = 500,
        balanceAssistEnabled: Bool = false,
        currentCashKrw: Int = 0,
        currentStocksKrw: Int = 0,
        currentBondsKrw: Int = 0
    ) {
        self.name = name
        self.monthlyContributionKrw = monthlyContributionKrw
        self.cashTargetBps = cashTargetBps
        self.stockTargetBps = stockTargetBps
        self.bondTargetBps = bondTargetBps
        self.toleranceBps = toleranceBps
        self.balanceAssistEnabled = balanceAssistEnabled
        self.currentCashKrw = currentCashKrw
        self.currentStocksKrw = currentStocksKrw
        self.currentBondsKrw = currentBondsKrw
        self.stockTargetsData = Data()
        self.createdAt = .now
        self.updatedAt = .now
    }

    var allocation: AllocationWeights {
        get { AllocationWeights(cash: cashTargetBps, stocks: stockTargetBps, bonds: bondTargetBps) }
        set {
            cashTargetBps = newValue.cash
            stockTargetBps = newValue.stocks
            bondTargetBps = newValue.bonds
            updatedAt = .now
        }
    }

    var holdings: PortfolioHoldings {
        PortfolioHoldings(cashKrw: currentCashKrw, stocksKrw: currentStocksKrw, bondsKrw: currentBondsKrw)
    }

    var stockTargets: [StockAllocationTarget] {
        get {
            guard !stockTargetsData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([StockAllocationTarget].self, from: stockTargetsData)) ?? []
        }
        set {
            stockTargetsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            updatedAt = .now
        }
    }

    func weight(for category: AssetCategory) -> Int { allocation[category] }
    func currentValue(for category: AssetCategory) -> Int { holdings[category] }
}

