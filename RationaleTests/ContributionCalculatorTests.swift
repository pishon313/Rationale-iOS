import XCTest
@testable import Rationale

final class ContributionCalculatorTests: XCTestCase {
    func testFixedAllocationKeepsExactWonTotal() throws {
        let result = try XCTUnwrap(ContributionCalculator.suggest(
            contributionKrw: 1_000_001,
            target: AllocationWeights(cash: 3_000, stocks: 6_000, bonds: 1_000),
            toleranceBps: 500,
            current: PortfolioHoldings(cashKrw: 0, stocksKrw: 0, bondsKrw: 0),
            balanceAssistEnabled: false
        ))

        XCTAssertEqual(result.source, .fixed)
        XCTAssertEqual(result.amountsKrw[.cash], 300_000)
        XCTAssertEqual(result.amountsKrw[.stocks], 600_001)
        XCTAssertEqual(result.amountsKrw[.bonds], 100_000)
        XCTAssertEqual(result.totalKrw, 1_000_001)
    }

    func testBalanceAssistPrioritizesUnderweightCategoriesWithoutSelling() throws {
        let result = try XCTUnwrap(ContributionCalculator.suggest(
            contributionKrw: 1_000_000,
            target: AllocationWeights(cash: 2_000, stocks: 7_000, bonds: 1_000),
            toleranceBps: 500,
            current: PortfolioHoldings(cashKrw: 0, stocksKrw: 10_000_000, bondsKrw: 0),
            balanceAssistEnabled: true
        ))

        XCTAssertEqual(result.source, .balanced)
        XCTAssertEqual(result.amountsKrw[.cash], 666_667)
        XCTAssertEqual(result.amountsKrw[.stocks], 0)
        XCTAssertEqual(result.amountsKrw[.bonds], 333_333)
        XCTAssertEqual(result.totalKrw, 1_000_000)
        XCTAssertEqual(result.weights.total, 10_000)
    }

    func testBalanceAssistKeepsPlanInsideTolerance() throws {
        let result = try XCTUnwrap(ContributionCalculator.suggest(
            contributionKrw: 1_000_000,
            target: AllocationWeights(cash: 3_000, stocks: 6_000, bonds: 1_000),
            toleranceBps: 100,
            current: PortfolioHoldings(cashKrw: 3_000_000, stocksKrw: 6_000_000, bondsKrw: 1_000_000),
            balanceAssistEnabled: true
        ))

        XCTAssertEqual(result.source, .withinTolerance)
        XCTAssertEqual(result.weights, AllocationWeights(cash: 3_000, stocks: 6_000, bonds: 1_000))
    }

    func testInvalidAllocationDoesNotProducePlan() {
        let result = ContributionCalculator.suggest(
            contributionKrw: 1_000_000,
            target: AllocationWeights(cash: 3_000, stocks: 5_000, bonds: 1_000),
            toleranceBps: 500,
            current: PortfolioHoldings(cashKrw: 0, stocksKrw: 0, bondsKrw: 0),
            balanceAssistEnabled: false
        )

        XCTAssertNil(result)
    }

    func testStockBudgetUsesExactTotal() throws {
        let targets = [
            StockAllocationTarget(ticker: "VOO", name: "S&P 500", targetBps: 3_333),
            StockAllocationTarget(ticker: "SOXX", name: "Semiconductor", targetBps: 3_333),
            StockAllocationTarget(ticker: "NVDA", name: "NVIDIA", targetBps: 3_334),
        ]
        let result = try XCTUnwrap(ContributionCalculator.allocateStockBudget(totalKrw: 100, targets: targets))

        XCTAssertEqual(result.values.reduce(0, +), 100)
        XCTAssertEqual(result[targets[0].id], 33)
        XCTAssertEqual(result[targets[1].id], 33)
        XCTAssertEqual(result[targets[2].id], 34)
    }
}

