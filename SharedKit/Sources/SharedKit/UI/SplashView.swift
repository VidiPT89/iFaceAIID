import SwiftUI

public struct SplashView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var isVisible = false
    private let onFinish: () -> Void

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            BrandColor.nearBlack.ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(BrandColor.gradient)
                        .frame(width: 96, height: 96)
                        .overlay(
                            Text("FA")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                        )
                        .shadow(color: BrandColor.accent.opacity(0.5), radius: isVisible ? 28 : 8)
                        .scaleEffect(isVisible ? 1 : 0.7)
                        .opacity(isVisible ? 1 : 0)

                    Text(localization.string(.appTitle))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(BrandColor.gradient)

                    Text(localization.string(.appTagline))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }

                VStack(spacing: 6) {
                    Text(localization.string(.splashDevelopedBy))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))

                    HStack(spacing: 10) {
                        Link("ividi.dev", destination: URL(string: "https://ividi.dev/")!)
                        Text("·").foregroundStyle(.white.opacity(0.4))
                        Link("github.com/VidiPT89", destination: URL(string: "https://github.com/VidiPT89/")!)
                    }
                    .font(.caption)
                    .tint(BrandColor.accentSecondary)
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 12)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { isVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation(.easeInOut(duration: 0.5)) { isVisible = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onFinish() }
            }
        }
    }
}
