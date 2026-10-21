# 🖐️ iFaceAIID

> Native macOS & iOS hand gesture recognition, built with SwiftUI and Apple's Vision framework, sharing one classification core across both platforms.

[Report Bug](https://github.com/VidiPT89/iFaceAIID/issues) · [Request Feature](https://github.com/VidiPT89/iFaceAIID/issues)

## ✨ Features

- ✅ Live hand gesture recognition for up to 2 hands at once, each labeled as your left/right hand — thumbs
  up/down, open palm, closed fist, peace sign, pointing, three fingers (W), shaka, rock on, the ASL/LGP "I
  love you" sign, and the fingerspelling letters A, D, F, I, L and O — via `VNDetectHumanHandPoseRequest`.
  This is a curated set of static hand shapes, **not** full sign-language recognition and **not** the full
  fingerspelling alphabet — real sign language (and most other letters, e.g. B, C, J, Z) needs a sequence
  model trained on real examples, or a way to measure finger curvature/overlap this classifier doesn't
  attempt
- ✅ Natural "mirror" camera preview on both platforms (iOS mirrors automatically; macOS cameras don't
  auto-mirror like a front-facing iPhone camera does, so it's mirrored explicitly to match)
- ✅ Facial expression recognition — smile, sad, surprised, angry, blinking — via `VNDetectFaceLandmarksRequest` heuristics. Tongue-out is **not** detected: Vision's face landmarks don't track the tongue at all
- ✅ Full head area shown as detected (forehead to chin), not just the eyes/nose/mouth mesh — Vision's landmark
  points never reach the forehead or hairline, so the whole head bounding box is drawn alongside the fine mesh
- ✅ Head movement recognition — nodding yes, shaking no, head tilt — from Vision's roll/yaw/pitch
- ✅ Approximate face identification — register a face and get recognized afterwards, using Vision's `VNGenerateImageFeaturePrintRequest` (no bundled third-party model; less precise than the web app's dedicated face-recognition net — see note below)
- ✅ 100% on-device processing — no video or biometric data ever leaves the Mac or the iPhone
- ✅ Shared `SharedKit` Swift package — one classification core for both native apps
- ✅ Animated hand-landmark and face-contour overlays drawn live over the camera preview
- ✅ Fluid SwiftUI animations, including an animated splash screen
- ✅ Runtime language switch — Português (PT-PT) and English
- ✅ Dark mode, Light mode, and System mode
- ✅ Custom color identity inspired by [ividi.dev](https://ividi.dev/) — burnt orange, amber and near-black

> **Note on face identification:** Apple doesn't expose a public, dedicated face-recognition API (unlike
> Face ID itself, which is private to the system). This app approximates it with Vision's general-purpose
> `VNGenerateImageFeaturePrintRequest` on the cropped face region — a reasonable, dependency-free
> approximation, but noticeably less accurate across different lighting/angles than the web app's
> face-api.js-based identification.

## 🛠️ Tech Stack

| Category    | Technology              |
|-------------|---------------------------|
| Language    | Swift 5.9+                 |
| UI          | SwiftUI (macOS 13+ / iOS 16+) |
| Vision      | Apple Vision framework      |
| Sharing     | Local Swift Package (SharedKit) |
| Project     | XcodeGen                    |

## 🚀 Quick Start

**Prerequisites**
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- macOS 13+ / iOS 16+ simulator or device

**Steps**

```bash
git clone https://github.com/VidiPT89/iFaceAIID.git
cd iFaceAIID

cd macOS-App && xcodegen generate && open iFaceAIID-Mac.xcodeproj
cd ../iOS-App && xcodegen generate && open iFaceAIID.xcodeproj
```

Select the corresponding scheme and run on a simulator or device.

## 📖 Usage

Press **Start camera** to detect hands, facial expressions and head movements together in one live preview.

- Show a hand shape to see its label and landmark overlay.
- Smile, nod or shake your head to see expression and movement badges.
- Type a name and press **Register face** to save a local sample. On macOS, registration is available only while a face is detected, and the name stays filled for additional samples.
- On macOS, a progress indicator appears during startup, which can be cancelled. If permission is denied, **Open camera settings** takes you to the relevant system settings. A missing camera has its own message.
- Press **Stop camera** to stop capture and clear the current results. You can start it again without recreating the window.

Switch language and appearance at any time from the toolbar.

## 🧪 Testing

```bash
xcodebuild -project macOS-App/iFaceAIID-Mac.xcodeproj -scheme iFaceAIID-Mac -destination 'platform=macOS' build
xcodebuild -project iOS-App/iFaceAIID.xcodeproj -scheme iFaceAIID -destination 'generic/platform=iOS Simulator' build
swift test --package-path SharedKit
swift test --package-path macOS-App
```

The macOS target uses Hardened Runtime and must be signed with the camera entitlement in
`macOS-App/iFaceAIID-Mac.entitlements`. Both Xcode configurations and `project.yml` reference it.
After building, verify the signed app with:

```bash
python3 scripts/check-camera-entitlement.py /path/to/iFaceAIID-Mac.app
```

`swift test` runs unit tests for the gesture and expression classifiers in `SharedKit` — no camera or device needed, since those are the parts most sensitive to threshold/geometry regressions.

## 📄 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

## 👨‍💻 Author

**David Arsénio Martins**

🌐 Website: [ividi.dev](https://ividi.dev/)
🐙 GitHub: [@VidiPT89](https://github.com/VidiPT89/)

## 🤝 Contributing

Contributions, issues and feature requests are welcome. Feel free to check the [issues page](https://github.com/VidiPT89/iFaceAIID/issues).

---

<p align="center">Developed by <a href="https://ividi.dev">David Arsénio Martins</a></p>
<p align="center">If you like this project, consider giving it a ⭐</p>
