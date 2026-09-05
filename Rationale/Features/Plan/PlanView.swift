import SwiftUI

struct PlanView: View {
    @Bindable var profile: PortfolioProfile
    @FocusState private var amountFocused: Bool

    private var suggestion: ContributionSuggestion? {
        ContributionCalculator.suggest(
            contributionKrw: max(0, profile.monthlyContributionKrw),
            target: profile.allocation,
            toleranceBps: profile.toleranceBps,
            current: profile.holdings,
            balanceAssistEnabled: profile.balanceAssistEnabled
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PortfolioSectionHeader(
                    eyebrow: "Contribution Plan",
                    title: "월 저축액을 자산별로\n나눠보세요.",
                    description: "금액을 바꾸면 저장된 Allocation으로 즉시 다시 계산합니다."
                )

                contributionInput

                if let suggestion {
                    calculationCard(suggestion)
                    if !profile.stockTargets.isEmpty {
                        stockPlanCard(suggestion)
                    }
                } else {
                    invalidAllocationCard
                }

                Label("Balance Assist는 신규 저축액만 배분하며 매도를 제안하지 않습니다. 모든 금액은 실행 전 직접 검토하세요.", systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { amountFocused = false }
            }
        }
    }

    private var contributionInput: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("01 · 전체 저축액")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(RationaleTheme.accent)
                    Text("이번에 저축할 총금액은 얼마인가요?")
                        .font(.headline)
                }
                Spacer()
                StatusPill(text: "KRW")
            }

            TextField("0", value: $profile.monthlyContributionKrw, format: .number)
                .keyboardType(.numberPad)
                .focused($amountFocused)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 16)
                .frame(height: 62)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityLabel("전체 저축액")

            HStack(spacing: 8) {
                amountButton("50만", value: 500_000)
                amountButton("100만", value: 1_000_000)
                amountButton("200만", value: 2_000_000)
            }
        }
        .rationaleCard()
    }

    private func amountButton(_ label: String, value: Int) -> some View {
        Button(label) { profile.monthlyContributionKrw = value; profile.updatedAt = .now }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(maxWidth: .infinity)
    }

    private func calculationCard(_ suggestion: ContributionSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                PortfolioSectionHeader(
                    eyebrow: "This Contribution",
                    title: "이번 달 실행 금액",
                    description: sourceDescription(suggestion.source)
                )
                StatusPill(text: sourceTitle(suggestion.source), color: suggestion.source == .balanced ? .orange : RationaleTheme.accent)
            }

            ForEach(AssetCategory.allCases) { category in
                VStack(spacing: 8) {
                    HStack {
                        CategoryLegend(category: category, subtitle: "전체 저축액의 \(PortfolioFormat.percent(suggestion.weights[category]))")
                        Spacer()
                        Text(PortfolioFormat.krw(suggestion.amountsKrw[category] ?? 0))
                            .font(.headline.weight(.bold))
                    }
                    GeometryReader { proxy in
                        Capsule()
                            .fill(category.color.opacity(0.16))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(category.color)
                                    .frame(width: proxy.size.width * CGFloat(suggestion.weights[category]) / 10_000)
                            }
                    }
                    .frame(height: 7)
                }
                if category != AssetCategory.allCases.last { Divider() }
            }

            HStack {
                Text("합계").font(.subheadline.weight(.semibold))
                Spacer()
                Text(PortfolioFormat.krw(suggestion.totalKrw)).font(.title3.weight(.bold))
            }
            .padding(.top, 2)
        }
        .rationaleCard()
    }

    private func stockPlanCard(_ suggestion: ContributionSuggestion) -> some View {
        let targets = profile.stockTargets
        let stockBudget = suggestion.amountsKrw[.stocks] ?? 0
        let amounts = ContributionCalculator.allocateStockBudget(totalKrw: stockBudget, targets: targets)
        return VStack(alignment: .leading, spacing: 16) {
            PortfolioSectionHeader(
                eyebrow: "Stock Detail",
                title: "주식 종목별 금액",
                description: amounts == nil ? "주식 세부 비중의 합계를 100%로 맞춰주세요." : "주식 예산 안에서 계산한 선택 항목입니다."
            )
            ForEach(targets) { target in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(target.ticker).font(.subheadline.weight(.bold))
                        Text(target.name).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(amounts?[target.id].map(PortfolioFormat.krw) ?? "—").font(.subheadline.weight(.semibold))
                        Text(PortfolioFormat.percent(target.targetBps)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if target.id != targets.last?.id { Divider() }
            }
        }
        .rationaleCard()
    }

    private var invalidAllocationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Allocation을 확인해 주세요", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("현금성 자산·주식·채권의 목표 비중 합계가 정확히 100%여야 계산할 수 있습니다. 현재 합계는 \(PortfolioFormat.percent(profile.allocation.total))입니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .rationaleCard()
    }

    private func sourceTitle(_ source: ContributionSuggestionSource) -> String {
        switch source {
        case .fixed: "고정 비율"
        case .withinTolerance: "기본 Plan 유지"
        case .balanced: "Balance Assist"
        }
    }

    private func sourceDescription(_ source: ContributionSuggestionSource) -> String {
        switch source {
        case .fixed: "저장된 Allocation 목표 비율을 그대로 사용합니다."
        case .withinTolerance: "현재 자산이 허용 범위 안에 있어 기본 비율을 유지합니다."
        case .balanced: "목표보다 부족한 자산군에 신규 저축액을 우선 배정합니다."
        }
    }
}

#Preview {
    NavigationStack { PlanView(profile: PortfolioProfile()) }
}

