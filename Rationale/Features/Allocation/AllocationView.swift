import SwiftData
import SwiftUI

struct AllocationView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: PortfolioProfile
    @State private var stockEditor: StockTargetDraft?
    @State private var showSaveConfirmation = false

    private var stockTargetTotal: Int { profile.stockTargets.reduce(0) { $0 + $1.targetBps } }
    private var stockTargetsValid: Bool { profile.stockTargets.isEmpty || stockTargetTotal == 10_000 }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PortfolioSectionHeader(
                    eyebrow: "Target Allocation",
                    title: "전체 자산의 목표 비중을\n정하세요.",
                    description: "현재 자산과 목표의 차이를 Plan의 다음 저축 계산에 연결합니다."
                )

                quickActions
                categoryTargetCard
                balanceAssistCard
                currentHoldingsCard
                stockDetailCard

                Button {
                    profile.updatedAt = .now
                    try? modelContext.save()
                    showSaveConfirmation = true
                } label: {
                    Label("Allocation 저장", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!profile.allocation.isValid || !stockTargetsValid)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Allocation")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $stockEditor) { draft in
            StockTargetEditor(draft: draft) { saved in
                saveStockTarget(saved)
            }
        }
        .alert("저장했습니다", isPresented: $showSaveConfirmation) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("다음 Plan 계산부터 이 Allocation을 사용합니다.")
        }
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            Button {
                profile.allocation = AllocationWeights(cash: 3_000, stocks: 6_000, bonds: 1_000)
            } label: {
                Label("30·60·10", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                useCurrentWeights()
            } label: {
                Label("현재 비중", systemImage: "scope")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(profile.holdings.totalKrw == 0)
        }
    }

    private var categoryTargetCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                PortfolioSectionHeader(
                    eyebrow: "01 · Core Allocation",
                    title: "고정 목표 비율",
                    description: "한 항목을 움직이면 나머지 비율을 자동 조정해 합계를 100%로 유지합니다."
                )
                StatusPill(text: PortfolioFormat.percent(profile.allocation.total), color: profile.allocation.isValid ? RationaleTheme.accent : .orange)
            }

            PortfolioDonut(weights: profile.allocation, centerValue: "100%", centerLabel: "목표 합계")
                .frame(maxWidth: .infinity)

            ForEach(AssetCategory.allCases) { category in
                VStack(spacing: 10) {
                    HStack {
                        CategoryLegend(category: category)
                        Spacer()
                        Text(PortfolioFormat.percent(profile.weight(for: category)))
                            .font(.headline.monospacedDigit())
                    }
                    Slider(value: targetBinding(for: category), in: 0...100, step: 1)
                        .tint(category.color)
                        .accessibilityLabel("\(category.title) 목표 비중")
                }
                if category != AssetCategory.allCases.last { Divider() }
            }
        }
        .rationaleCard()
    }

    private var balanceAssistCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $profile.balanceAssistEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Balance Assist", systemImage: "scale.3d")
                        .font(.headline)
                    Text("목표 허용 범위를 벗어날 때 부족한 자산군에 신규 저축액을 우선 배정합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if profile.balanceAssistEnabled {
                Divider()
                Stepper(value: $profile.toleranceBps, in: 0...2_000, step: 100) {
                    HStack {
                        Text("자산군 허용 오차")
                        Spacer()
                        Text("±\(PortfolioFormat.percent(profile.toleranceBps))")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                    }
                }
            }
        }
        .rationaleCard()
    }

    private var currentHoldingsCard: some View {
        DisclosureGroup {
            VStack(spacing: 14) {
                Text("증권 계좌 연결 전에는 현재 금액을 직접 입력해 Balance Assist를 시험할 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(AssetCategory.allCases) { category in
                    HStack {
                        CategoryLegend(category: category)
                        Spacer()
                        TextField("0", value: holdingBinding(for: category), format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("현재 \(category.title) 금액")
                    }
                }
                HStack {
                    Text("현재 자산 합계").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(PortfolioFormat.krw(profile.holdings.totalKrw)).font(.subheadline.weight(.bold))
                }
            }
            .padding(.top, 14)
        } label: {
            Label("현재 자산 금액 · 선택", systemImage: "wallet.bifold")
                .font(.headline)
        }
        .rationaleCard()
    }

    private var stockDetailCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                PortfolioSectionHeader(
                    eyebrow: "02 · Optional",
                    title: "주식 세부 목표",
                    description: "필수는 아닙니다. 설정하면 Plan의 주식 예산을 종목별로 나눕니다."
                )
                Button {
                    let remaining = max(0, 10_000 - stockTargetTotal)
                    stockEditor = StockTargetDraft(id: UUID(), ticker: "", name: "", targetBps: remaining, currentValueKrw: 0, isNew: true)
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("주식 세부 목표 추가")
            }

            if profile.stockTargets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundStyle(RationaleTheme.accent)
                    Text("종목별 목표를 사용하지 않습니다")
                        .font(.subheadline.weight(.semibold))
                    Text("전체 주식 비중만으로도 Allocation과 Plan을 사용할 수 있습니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            } else {
                ForEach(profile.stockTargets) { target in
                    stockTargetRow(target)
                    if target.id != profile.stockTargets.last?.id { Divider() }
                }

                HStack {
                    Text("주식 세부 비중 합계").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(PortfolioFormat.percent(stockTargetTotal))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(stockTargetsValid ? RationaleTheme.accent : .orange)
                }

                if !stockTargetsValid {
                    Label("세부 비중 합계를 100%로 맞춰야 종목별 금액을 계산할 수 있습니다.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .rationaleCard()
    }

    private func stockTargetRow(_ target: StockAllocationTarget) -> some View {
        Button {
            stockEditor = StockTargetDraft(target: target)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(target.ticker.isEmpty ? "티커 미입력" : target.ticker)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(target.name.isEmpty ? "종목 이름" : target.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(PortfolioFormat.percent(target.targetBps))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text(PortfolioFormat.krw(target.currentValueKrw))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("삭제", systemImage: "trash", role: .destructive) { deleteStockTarget(target.id) }
        }
    }

    private func targetBinding(for category: AssetCategory) -> Binding<Double> {
        Binding(
            get: { Double(profile.weight(for: category)) / 100 },
            set: { setTarget(category, bps: Int($0.rounded()) * 100) }
        )
    }

    private func holdingBinding(for category: AssetCategory) -> Binding<Int> {
        Binding(
            get: { profile.currentValue(for: category) },
            set: { value in
                let safeValue = max(0, value)
                switch category {
                case .cash: profile.currentCashKrw = safeValue
                case .stocks: profile.currentStocksKrw = safeValue
                case .bonds: profile.currentBondsKrw = safeValue
                }
                profile.updatedAt = .now
            }
        )
    }

    private func setTarget(_ category: AssetCategory, bps: Int) {
        let safeBps = min(max(bps, 0), 10_000)
        let others = AssetCategory.allCases.filter { $0 != category }
        let currentOtherWeights = others.map { profile.weight(for: $0) }
        let basis = currentOtherWeights.reduce(0, +) == 0 ? [1, 1] : currentOtherWeights
        let distributed = ContributionCalculator.allocateExactly(total: 10_000 - safeBps, integerWeights: basis)
        var allocation = profile.allocation
        allocation[category] = safeBps
        for (index, other) in others.enumerated() { allocation[other] = distributed[index] }
        profile.allocation = allocation
    }

    private func useCurrentWeights() {
        guard profile.holdings.totalKrw > 0 else { return }
        let bps = ContributionCalculator.allocateExactly(total: 10_000, integerWeights: AssetCategory.allCases.map { profile.currentValue(for: $0) })
        profile.allocation = AllocationWeights(cash: bps[0], stocks: bps[1], bonds: bps[2])
    }

    private func saveStockTarget(_ draft: StockTargetDraft) {
        var targets = profile.stockTargets
        let target = StockAllocationTarget(id: draft.id, ticker: draft.ticker.uppercased(), name: draft.name, targetBps: min(max(draft.targetBps, 0), 10_000), currentValueKrw: max(0, draft.currentValueKrw))
        if let index = targets.firstIndex(where: { $0.id == draft.id }) {
            targets[index] = target
        } else {
            targets.append(target)
        }
        profile.stockTargets = targets
    }

    private func deleteStockTarget(_ id: UUID) {
        profile.stockTargets = profile.stockTargets.filter { $0.id != id }
    }
}

private struct StockTargetDraft: Identifiable {
    var id: UUID
    var ticker: String
    var name: String
    var targetBps: Int
    var currentValueKrw: Int
    var isNew: Bool

    init(id: UUID, ticker: String, name: String, targetBps: Int, currentValueKrw: Int, isNew: Bool) {
        self.id = id
        self.ticker = ticker
        self.name = name
        self.targetBps = targetBps
        self.currentValueKrw = currentValueKrw
        self.isNew = isNew
    }

    init(target: StockAllocationTarget) {
        self.init(id: target.id, ticker: target.ticker, name: target.name, targetBps: target.targetBps, currentValueKrw: target.currentValueKrw, isNew: false)
    }
}

private struct StockTargetEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ticker: String
    @State private var name: String
    @State private var targetPercent: Double
    @State private var currentValueKrw: Int
    let draft: StockTargetDraft
    let onSave: (StockTargetDraft) -> Void

    init(draft: StockTargetDraft, onSave: @escaping (StockTargetDraft) -> Void) {
        self.draft = draft
        self.onSave = onSave
        _ticker = State(initialValue: draft.ticker)
        _name = State(initialValue: draft.name)
        _targetPercent = State(initialValue: Double(draft.targetBps) / 100)
        _currentValueKrw = State(initialValue: draft.currentValueKrw)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("종목") {
                    TextField("티커", text: $ticker)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("종목 이름", text: $name)
                }
                Section("주식 예산 안의 목표 비중") {
                    HStack {
                        Slider(value: $targetPercent, in: 0...100, step: 1)
                        Text(targetPercent / 100, format: .percent.precision(.fractionLength(0)))
                            .font(.subheadline.monospacedDigit())
                            .frame(width: 52, alignment: .trailing)
                    }
                }
                Section("현재 보유 금액 · 선택") {
                    TextField("0", value: $currentValueKrw, format: .number)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(draft.isNew ? "종목 목표 추가" : "종목 목표 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(StockTargetDraft(id: draft.id, ticker: ticker.trimmingCharacters(in: .whitespacesAndNewlines), name: name.trimmingCharacters(in: .whitespacesAndNewlines), targetBps: Int(targetPercent.rounded()) * 100, currentValueKrw: currentValueKrw, isNew: draft.isNew))
                        dismiss()
                    }
                    .disabled(ticker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { AllocationView(profile: PortfolioProfile()) }
}

