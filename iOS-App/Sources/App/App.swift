import SwiftUI
import SharedKit

@main
struct FaceAIIDApp: App {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                if showSplash {
                    SplashView { showSplash = false }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .preferredColorScheme(themeManager.theme.colorScheme)
        }
    }
}
