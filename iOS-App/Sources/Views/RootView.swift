import SwiftUI
import SharedKit

struct RootView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var mode: AppMode = .hands

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(localization.string(.appTitle))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Spacer()
                ControlsBar()
            }
            .padding(.horizontal)

            Picker("", selection: $mode) {
                Text(localization.string(.modeHands)).tag(AppMode.hands)
                Text(localization.string(.modeFace)).tag(AppMode.face)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            switch mode {
            case .hands: CameraView()
            case .face: FaceView()
            }
        }
        .padding(.top)
    }
}
