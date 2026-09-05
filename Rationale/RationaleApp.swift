import Foundation
import SwiftData
import SwiftUI

@main
struct RationaleApp: App {
    private let modelContainer: ModelContainer = {
        do {
            let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            let configuration = ModelConfiguration(isStoredInMemoryOnly: isRunningTests)
            return try ModelContainer(for: PortfolioProfile.self, configurations: configuration)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
