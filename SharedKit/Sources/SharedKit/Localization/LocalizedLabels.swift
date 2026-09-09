/// Maps each detection enum to its localized display string, so the four
/// views (iOS/macOS × Hands/Face) share one definition instead of repeating
/// the same switch statement.
extension DetectedGesture {
    public var localizedKey: LocalizedKey {
        switch self {
        case .thumbsUp: return .gestureThumbsUp
        case .openPalm: return .gestureOpenPalm
        case .closedFist: return .gestureClosedFist
        case .peaceSign: return .gesturePeaceSign
        case .pointing: return .gesturePointing
        case .none: return .gestureNone
        }
    }
}

extension FacialExpression {
    public var localizedKey: LocalizedKey {
        switch self {
        case .smile: return .expressionSmile
        case .sad: return .expressionSad
        case .surprised: return .expressionSurprised
        case .angry: return .expressionAngry
        case .blink: return .expressionBlink
        case .none: return .expressionNone
        }
    }
}

extension HeadMovement {
    public var localizedKey: LocalizedKey {
        switch self {
        case .nodYes: return .headNodYes
        case .shakeNo: return .headShakeNo
        case .tilt: return .headTilt
        case .none: return .headNone
        }
    }
}
