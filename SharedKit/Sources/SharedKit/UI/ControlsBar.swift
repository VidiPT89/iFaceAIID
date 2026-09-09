import SwiftUI

public struct ControlsBar: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 12) {
            Picker("", selection: $localization.language) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayCode).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 100)

            Picker("", selection: $themeManager.theme) {
                Image(systemName: "sun.max.fill").tag(AppTheme.light)
                Image(systemName: "moon.fill").tag(AppTheme.dark)
                Image(systemName: "circle.lefthalf.filled").tag(AppTheme.system)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
        }
    }
}
