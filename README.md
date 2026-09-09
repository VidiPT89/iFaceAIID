# 🖐️ iFaceAIID

> Native macOS & iOS hand gesture recognition, built with SwiftUI and Apple's Vision framework, sharing one classification core across both platforms.

[Report Bug](https://github.com/VidiPT89/iFaceAIID/issues) · [Request Feature](https://github.com/VidiPT89/iFaceAIID/issues)

## ✨ Features

- ✅ Live hand gesture recognition for up to 2 hands at once, each labeled as your left/right hand — thumbs
  up/down, open palm, closed fist, peace sign, pointing, three fingers (W), shaka, the ASL/LGP "I love
  you" sign, and the fingerspelling letters L and O — via `VNDetectHumanHandPoseRequest`. This is a curated
  set of static hand shapes, **not** full sign-language recognition (which needs a sequence model tracking
  movement over time — most fingerspelling letters, e.g. J or Z, also need motion and aren't included)
- ✅ Natural "mirror" camera preview on both platforms (iOS mirrors automatically; macOS cameras don't
  auto-mirror like a front-facing iPhone camera does, so it's mirrored explicitly to match)
- ✅ Facial expression recognition — smile, sad, surprised, angry, blinking — via `VNDetectFaceLandmarksRequest` heuristics
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

Launch either app and switch between **Hands** and **Face** with the segmented control at the top:

- **Hands**: show a hand shape to get 👍 / ✋ / ✊ / ✌️ / ☝️ recognized in an animated badge, with the hand
  skeleton drawn live over the feed.
- **Face**: smile, frown, look surprised, nod or shake your head for expression/head-movement badges; type
  a name and tap **Register face** to store it, then get recognized (or "not recognized") live.

Switch language and appearance at any time from the toolbar.

## 🧪 Testing

```bash
xcodebuild -project macOS-App/iFaceAIID-Mac.xcodeproj -scheme iFaceAIID-Mac -destination 'platform=macOS' build
xcodebuild -project iOS-App/iFaceAIID.xcodeproj -scheme iFaceAIID -destination 'generic/platform=iOS Simulator' build
```

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
