/// Maps each detection enum to its localized display string in one place.
extension DetectedGesture {
    public var localizedKey: LocalizedKey {
        switch self {
        case .thumbsUp: return .gestureThumbsUp
        case .openPalm: return .gestureOpenPalm
        case .closedFist: return .gestureClosedFist
        case .peaceSign: return .gesturePeaceSign
        case .pointing: return .gesturePointing
        case .thumbsDown: return .gestureThumbsDown
        case .threeFingers: return .gestureThreeFingers
        case .shaka: return .gestureShaka
        case .iLoveYou: return .gestureILoveYou
        case .letterA: return .gestureLetterA
        case .letterD: return .gestureLetterD
        case .letterF: return .gestureLetterF
        case .letterI: return .gestureLetterI
        case .letterL: return .gestureLetterL
        case .letterO: return .gestureLetterO
        case .rockOn: return .gestureRockOn
        case .letterB: return .gestureLetterB
        case .letterU: return .gestureLetterU
        case .fingersCrossed: return .gestureFingersCrossed
        case .none: return .gestureNone
        }
    }
}

extension Handedness {
    public var localizedKey: LocalizedKey? {
        switch self {
        case .left: return .handLeft
        case .right: return .handRight
        case .unknown: return nil
        }
    }
}

extension DetectedHand {
    /// "Left hand — Open palm", or just the gesture text when handedness is
    /// unknown.
    @MainActor
    public func localizedLabel(using localization: LocalizationManager) -> String {
        let gestureText = localization.string(gesture.localizedKey)
        guard let key = handedness.localizedKey else { return gestureText }
        return "\(localization.string(key)) — \(gestureText)"
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
        case .laugh: return .expressionLaugh
        case .kiss: return .expressionKiss
        case .mouthOpen: return .expressionMouthOpen
        case .browsRaised: return .expressionBrowsRaised
        case .wink: return .expressionWink
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
        case .turnLeft: return .headTurnLeft
        case .turnRight: return .headTurnRight
        case .lookUp: return .headLookUp
        case .lookDown: return .headLookDown
        case .none: return .headNone
        }
    }
}
