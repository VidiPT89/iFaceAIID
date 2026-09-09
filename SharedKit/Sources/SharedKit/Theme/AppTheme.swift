import SwiftUI
import Combine

public enum AppTheme: String, CaseIterable, Sendable {
    case light
    case dark
    case system

    public var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

@MainActor
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    private static let storageKey = "faceaiid.theme"

    @Published public var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey) }
    }

    private init() {
        if let stored = UserDefaults.standard.string(forKey: Self.storageKey),
           let theme = AppTheme(rawValue: stored) {
            self.theme = theme
        } else {
            self.theme = .system
        }
    }
}

/// Brand palette shared by both apps — burnt orange, amber and near-black, matching ividi.dev.
public enum BrandColor {
    public static let accent = Color(red: 1.0, green: 0.48, blue: 0.10)      // burnt orange
    public static let accentSecondary = Color(red: 1.0, green: 0.72, blue: 0.01) // amber
    public static let accentTertiary = Color(red: 0.85, green: 0.29, blue: 0.10) // deep orange
    public static let nearBlack = Color(red: 0.07, green: 0.05, blue: 0.035)

    public static var gradient: LinearGradient {
        LinearGradient(
            colors: [accentTertiary, accent, accentSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
