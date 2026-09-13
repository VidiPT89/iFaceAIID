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

            UnifiedView()

            Spacer()

            VStack(spacing: 4) {
                Text(localization.string(.footerPrivacy))
                Text(localization.string(.footerDevelopedBy) + " David Arsénio Martins")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 700)
    }
}
