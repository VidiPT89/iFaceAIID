# 🖐️ iFaceAIID

> Native macOS & iOS hand gesture recognition, built with SwiftUI and Apple's Vision framework, sharing one classification core across both platforms.

[Report Bug](https://github.com/VidiPT89/iFaceAIID/issues) · [Request Feature](https://github.com/VidiPT89/iFaceAIID/issues)

## ✨ Features

- ✅ Live hand gesture recognition — thumbs up, open palm, closed fist — via `VNDetectHumanHandPoseRequest`
- ✅ 100% on-device processing — no video ever leaves the Mac or the iPhone
- ✅ Shared `SharedKit` Swift package — one classification core for both native apps
- ✅ Animated hand-landmark overlay drawn live over the camera preview
- ✅ Fluid SwiftUI animations, including an animated splash screen
- ✅ Runtime language switch — Português (PT-PT) and English
- ✅ Dark mode, Light mode, and System mode
- ✅ Custom color identity inspired by [ividi.dev](https://ividi.dev/) — burnt orange, amber and near-black

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

Launch either app, allow the camera permission prompt, and show your hand to the camera. The app draws
the detected hand landmarks live and surfaces the recognized gesture (👍 thumbs up, ✋ open palm, ✊ closed
fist) in an animated badge. Switch language and appearance at any time from the toolbar.

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
