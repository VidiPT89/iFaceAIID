/// The lifecycle of the camera capture session, so the view can render the
/// right state instead of assuming the camera started just because the user
/// tapped the button.
public enum CaptureStatus: Sendable, Equatable {
    case idle
    case running
    case denied
    case failed
}
