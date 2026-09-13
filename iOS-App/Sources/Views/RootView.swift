import SwiftUI
import SharedKit

struct RootView: View {
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(localization.string(.appTitle))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Spacer()
                ControlsBar()
            }
            .padding(.horizontal)

            UnifiedView()
        }
        .padding(.top)
    }
}
