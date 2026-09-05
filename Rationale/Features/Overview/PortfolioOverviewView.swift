import SwiftUI

struct PortfolioOverviewView: View {
    @Bindable var profile: PortfolioProfile

    private var suggestion: ContributionSuggestion? {
        ContributionCalculator.suggest(
            contributionKrw: profile.monthlyContributionKrw,
            target: profile.allocation,
            toleranceBps: profile.toleranceBps,
            current: profile.holdings,
            balanceAssistEnabled: profile.balanceAssistEnabled
        )
    }

    private var currentWeights: AllocationWeights? {
        guard profile.holdings.totalKrw > 0 else { return nil }
        let bps = ContributionCalculator.allocateExactly(
            total: 10_000,
            integerWeights: AssetCategory.allCases.map { profile.currentValue(for: $0) }
        )
        return AllocationWeights(cash: bps[0], stocks: bps[1], bonds: bps[2])
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PortfolioSectionHeader(
                    eyebrow: "Portfolio Overview",
                    title: "자산과 다음 저축 계획을\n한눈에 보세요.",
                    description: "실제 보유 자산과 월 저축 계획을 분리해 보여줍니다."
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    PortfolioMetricCard(
                        label: "현재 포트폴리오",
                        value: PortfolioFormat.krw(profile.holdings.totalKrw),
                        help: profile.holdings.totalKrw > 0 ? "입력된 현재 자산" : "자산 입력 전"
                    )
                    PortfolioMetricCard(
                        label: "다음 전체 저축액",
                        value: PortfolioFormat.krw(profile.monthlyContributionKrw),
                        help: "이번 달 계획 기준"
                    )
                    PortfolioMetricCard(
                        label: "Allocation",
                        value: profile.allocation.isValid ? "100%" : PortfolioFormat.percent(profile.allocation.total),
                        help: profile.allocation.isValid ? "목표 비중 설정됨" : "비중 합계를 확인하세요",
                        tone: profile.allocation.isValid ? RationaleTheme.accent : RationaleTheme.warning
                    )
                    PortfolioMetricCard(
                        label: "계산 방식",
                        value: profile.balanceAssistEnabled ? "Balance Assist" : "고정 비율",
                        help: profile.balanceAssistEnabled ? "부족한 자산 우선" : "목표 비율 그대로"
                    )
                }

                currentAllocationCard
                nextContributionCard

                if !profile.stockTargets.isEmpty {
                    stockDetailCard
                }

                Label("계좌가 없어도 Allocation과 Plan을 먼저 만들 수 있습니다. 계산 결과는 주문이나 매매 추천이 아닙니다.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentAllocationCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                PortfolioSectionHeader(
                    eyebrow: "Current Assets",
                    title: "현재 자산 배분",
                    description: profile.holdings.totalKrw > 0 ? "현재 비중과 목표 허용 범위를 비교합니다." : "자산이 없어도 목표 Allocation은 확인할 수 있습니다."
                )
                StatusPill(text: profile.holdings.totalKrw > 0 ? "현재" : "목표")
            }

            PortfolioDonut(
                weights: currentWeights ?? profile.allocation,
                centerValue: profile.holdings.totalKrw > 0 ? PortfolioFormat.krw(profile.holdings.totalKrw) : "목표",
                centerLabel: profile.holdings.totalKrw > 0 ? "현재 평가 금액" : "Allocation"
            )
            .frame(maxWidth: .infinity)

            VStack(spacing: 16) {
                ForEach(AssetCategory.allCases) { category in
                    let currentBps = currentWeights?[category]
                    let targetBps = profile.weight(for: category)
                    VStack(spacing: 8) {
                        HStack {
                            CategoryLegend(category: category, subtitle: PortfolioFormat.krw(profile.currentValue(for: category)))
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(currentBps.map(PortfolioFormat.percent) ?? "—")
                                    .font(.subheadline.weight(.bold))
                                Text("목표 \(PortfolioFormat.percent(targetBps))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        AllocationRangeBar(currentBps: currentBps, targetBps: targetBps, toleranceBps: profile.toleranceBps, color: category.color)
                    }
                    if category != AssetCategory.allCases.last { Divider() }
                }
            }
        }
        .rationaleCard()
    }

    private var nextContributionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                PortfolioSectionHeader(
                    eyebrow: "Next Contribution",
                    title: "다음 저축 계획",
                    description: "Allocation을 이번 달 저축액으로 환산합니다."
                )
                if let suggestion {
                    StatusPill(text: sourceTitle(suggestion.source), color: suggestion.source == .balanced ? .orange : RationaleTheme.accent)
                }
            }

            HStack {
                Text("전체 저축액").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text(PortfolioFormat.krw(profile.monthlyContributionKrw)).font(.title3.weight(.bold))
            }
            .padding(14)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let suggestion {
                ForEach(AssetCategory.allCases) { category in
                    HStack {
                        CategoryLegend(category: category, subtitle: PortfolioFormat.percent(suggestion.weights[category]))
                        Spacer()
                        Text(PortfolioFormat.krw(suggestion.amountsKrw[category] ?? 0))
                            .font(.subheadline.weight(.bold))
                    }
                    if category != AssetCategory.allCases.last { Divider() }
                }
            } else {
                Label("Allocation 비중의 합계가 100%가 되어야 계산할 수 있습니다.", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
        .rationaleCard()
    }

    private var stockDetailCard: some View {
        let targets = profile.stockTargets
        let stockBudget = suggestion?.amountsKrw[.stocks] ?? 0
        let amounts = ContributionCalculator.allocateStockBudget(totalKrw: stockBudget, targets: targets)
        return VStack(alignment: .leading, spacing: 16) {
            PortfolioSectionHeader(
                eyebrow: "Optional Stock Detail",
                title: "종목별 다음 투자 계획",
                description: "주식 예산을 선택한 종목 목표 비율로 나눕니다."
            )
            ForEach(targets) { target in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(target.ticker).font(.subheadline.weight(.bold))
                        Text(target.name.isEmpty ? "이름 없음" : target.name).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(amounts?[target.id].map(PortfolioFormat.krw) ?? "—").font(.subheadline.weight(.semibold))
                        Text(PortfolioFormat.percent(target.targetBps)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if target.id != targets.last?.id { Divider() }
            }
        }
        .rationaleCard()
    }

    private func sourceTitle(_ source: ContributionSuggestionSource) -> String {
        switch source {
        case .fixed: "고정 비율"
        case .withinTolerance: "기본 Plan 유지"
        case .balanced: "균형 맞추기"
        }
    }
}

#Preview {
    NavigationStack { PortfolioOverviewView(profile: PortfolioProfile()) }
}

