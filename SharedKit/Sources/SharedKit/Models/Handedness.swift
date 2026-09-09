/// Which physical hand this is — "the hand that looks like the user's left
/// hand when they look at the (mirrored) preview", not a raw anatomical
/// label from whatever coordinate space the vision framework happens to
/// use internally.
public enum Handedness: String, Sendable {
    case left
    case right
    case unknown
}
