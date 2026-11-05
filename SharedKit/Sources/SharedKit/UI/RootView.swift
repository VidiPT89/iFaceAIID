import SwiftUI

/// The whole app screen, shared by iOS and macOS.
public struct RootView: View {
    @ObservedObject private var localization = LocalizationManager.shared

    public init() {}

    public var body: some View {
        #if os(iOS)
        // A full-width 3:4 preview plus the controls below it is taller than
        // smaller iPhones' screens; scrolling keeps everything reachable.
        ScrollView {
            content
                .padding([.horizontal, .top])
                .padding(.bottom, 12)
        }
        #else
        content
            .padding(24)
            .frame(minWidth: 560, minHeight: 700)
        #endif
    }

    private var title: some View {
        Text(localization.string(.appTitle))
            .font(.system(.title2, design: .rounded, weight: .bold))
            .lineLimit(1)
            .fixedSize()
    }

    private var content: some View {
        VStack(spacing: 12) {
            // Title and controls side by side when they fit (Mac, iPad);
            // stacked on a phone-width screen instead of wrapping the title.
            ViewThatFits(in: .horizontal) {
                HStack {
                    title
                    Spacer()
                    ControlsBar()
                }
                VStack(spacing: 8) {
                    title
                    ControlsBar()
                }
            }

            DetectionView()

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                Text(localization.string(.footerPrivacy))
                Text(localization.string(.footerDevelopedBy) + " David Arsénio Martins")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
    }
}
