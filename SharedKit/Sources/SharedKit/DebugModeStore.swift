import Foundation

/// Off by default: the raw per-frame numbers (thumb angle, pinch ratio,
/// expression scores) are useful for diagnosing a specific gesture that
/// won't classify right, but clutter the view for normal use — this makes
/// them opt-in instead of always-on.
@MainActor
public final class DebugModeStore: ObservableObject {
    public static let shared = DebugModeStore()

    private static let storageKey = "faceaiid.debugMode"

    @Published public var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.storageKey) }
    }

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.storageKey)
    }
}
