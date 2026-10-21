import SwiftUI

public struct ControlsBar: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var debugMode = DebugModeStore.shared

    public init() {}

    // AppKit segmented controls can invoke their binding setter during a
    // SwiftUI update. Publish observable changes on the next MainActor turn.
    private var languageSelection: Binding<AppLanguage> {
        Binding(get: { localization.language }, set: { language in
            Task { @MainActor in
                guard localization.language != language else { return }
                localization.language = language
            }
        })
    }

    private var themeSelection: Binding<AppTheme> {
        Binding(get: { themeManager.theme }, set: { theme in
            Task { @MainActor in
                guard themeManager.theme != theme else { return }
                themeManager.theme = theme
            }
        })
    }

    public var body: some View {
        HStack(spacing: 12) {
            Picker("", selection: languageSelection) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayCode).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 100)

            Picker("", selection: themeSelection) {
                Image(systemName: "sun.max.fill").tag(AppTheme.light)
                Image(systemName: "moon.fill").tag(AppTheme.dark)
                Image(systemName: "circle.lefthalf.filled").tag(AppTheme.system)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)

            Button {
                debugMode.isEnabled.toggle()
            } label: {
                Image(systemName: "ladybug.fill")
                    .foregroundStyle(debugMode.isEnabled ? BrandColor.accent : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
