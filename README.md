# 🖐️ iFaceAIID

> Native macOS & iOS hand gesture recognition, built with SwiftUI and Apple's Vision framework, sharing one classification core across both platforms.

[Report Bug](https://github.com/VidiPT89/iFaceAIID/issues) · [Request Feature](https://github.com/VidiPT89/iFaceAIID/issues)

## ✨ Features

- ✅ Live hand gesture recognition for up to 2 hands at once, each labeled as your left/right hand — thumbs
  up/down, open palm, closed fist, peace sign, crossed fingers, pointing, three fingers (W), shaka, rock on,
  the ASL/LGP "I love you" sign, OK, and the fingerspelling letters A, B, D, F, I, L, O and U — via
  `VNDetectHumanHandPoseRequest`. Fingers count as folded only when clearly folded, so a relaxed, half-open
  hand reads as "nothing" rather than a wrong letter. This is a curated set of static hand shapes, **not**
  full sign-language recognition
- ✅ Natural "mirror" camera preview on both platforms (iOS mirrors automatically; macOS cameras don't
  auto-mirror like a front-facing iPhone camera does, so it's mirrored explicitly to match)
- ✅ Facial expression recognition — smile, laugh, sad, surprised, angry, kiss, mouth open, raised eyebrows, wink and eyes closed — from `VNDetectFaceLandmarksRequest` geometry, measured against each person's own neutral face. Tongue-out and puffed cheeks are **not** detected: Vision's landmarks don't track the tongue or the cheeks
- ✅ Full head area shown as detected (forehead to chin), not just the eyes/nose/mouth mesh — Vision's landmark
  points never reach the forehead or hairline, so the whole head bounding box is drawn alongside the fine mesh
- ✅ Head movement recognition — nodding yes, shaking no, head tilt, and looking left/right/up/down — from Vision's yaw/pitch/roll (face rectangles revision 3, which also reports pitch)
- ✅ Approximate face identification — register a face and get recognized afterwards, using Vision's `VNGenerateImageFeaturePrintRequest` (no bundled third-party model; less precise than the web app's dedicated face-recognition net — see note below). A name is only shown when it wins several checks in a row and clearly beats any other registered person, and only frontal, upright faces are compared or registered
- ✅ 100% on-device processing — no video or biometric data ever leaves the Mac or the iPhone
- ✅ Shared `SharedKit` Swift package — the classifiers, the camera/Vision capture service and the whole UI live here once; each app target is just its `@main` entry point, icons and Info.plist
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
- Type a name and press **Register face** to save a local sample. Registration is available only while a face is detected, and the name stays filled for additional samples.
- A progress indicator appears during startup, which can be cancelled. If permission is denied, **Open camera settings** takes you to the relevant settings. A missing camera has its own message.
- Press **Stop camera** to stop capture and clear the current results. You can start it again without recreating the window.

Switch language and appearance at any time from the toolbar.

## 🧪 Testing

```bash
xcodebuild -project macOS-App/iFaceAIID-Mac.xcodeproj -scheme iFaceAIID-Mac -destination 'platform=macOS' build
xcodebuild -project iOS-App/iFaceAIID.xcodeproj -scheme iFaceAIID -destination 'generic/platform=iOS Simulator' build
swift test --package-path SharedKit
```

The macOS target uses Hardened Runtime and must be signed with the camera entitlement in
`macOS-App/iFaceAIID-Mac.entitlements`. Both Xcode configurations and `project.yml` reference it.
After building, verify the signed app with:

```bash
python3 scripts/check-camera-entitlement.py /path/to/iFaceAIID-Mac.app
```

`swift test` runs unit tests for the gesture, expression, head and identity logic — including hand points Vision produced on MediaPipe's public test photos (`SharedKit/Tests/SharedKitTests/Fixtures`) — and the camera lifecycle (permission handling, start/stop races) in `SharedKit` — no camera or device needed.

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
