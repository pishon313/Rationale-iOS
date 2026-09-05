import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PortfolioProfile.createdAt) private var profiles: [PortfolioProfile]
    @State private var didCreateInitialProfile = false

    var body: some View {
        Group {
            if let profile = profiles.first {
                PortfolioTabView(profile: profile)
            } else {
                ProgressView("포트폴리오를 준비하는 중입니다")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                    .task { createInitialProfileIfNeeded() }
            }
        }
        .tint(RationaleTheme.accent)
    }

    private func createInitialProfileIfNeeded() {
        guard !didCreateInitialProfile else { return }
        didCreateInitialProfile = true
        modelContext.insert(PortfolioProfile())
        try? modelContext.save()
    }
}

private struct PortfolioTabView: View {
    let profile: PortfolioProfile

    var body: some View {
        TabView {
            NavigationStack { PortfolioOverviewView(profile: profile) }
                .tabItem { Label("개요", systemImage: "chart.pie.fill") }
            NavigationStack { AllocationView(profile: profile) }
                .tabItem { Label("배분", systemImage: "slider.horizontal.3") }
            NavigationStack { PlanView(profile: profile) }
                .tabItem { Label("계획", systemImage: "calendar.badge.clock") }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: PortfolioProfile.self, inMemory: true)
}
