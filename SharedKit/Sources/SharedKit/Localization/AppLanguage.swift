import Foundation
import Combine

public enum AppLanguage: String, CaseIterable, Sendable {
    case portuguese = "pt"
    case english = "en"

    public var displayCode: String {
        switch self {
        case .portuguese: return "PT"
        case .english: return "EN"
        }
    }
}

public enum LocalizedKey: String {
    case appTitle
    case appTagline
    case splashDevelopedBy
    case heroTitle
    case heroSubtitle
    case cameraStart
    case cameraStop
    case cameraPermission
    case cameraError
    case gestureNone
    case gestureThumbsUp
    case gestureOpenPalm
    case gestureClosedFist
    case themeLight
    case themeDark
    case themeSystem
    case footerPrivacy
    case footerDevelopedBy
}

private let strings: [AppLanguage: [LocalizedKey: String]] = [
    .portuguese: [
        .appTitle: "Face AI ID",
        .appTagline: "Reconhecimento de gestos em tempo real",
        .splashDevelopedBy: "Criado por David Arsénio Martins",
        .heroTitle: "Reconhecimento de gestos",
        .heroSubtitle: "Aponta a câmara e mostra a mão. Tudo é processado localmente no dispositivo.",
        .cameraStart: "Iniciar câmara",
        .cameraStop: "Parar câmara",
        .cameraPermission: "É necessário dar permissão de acesso à câmara.",
        .cameraError: "Não foi possível aceder à câmara.",
        .gestureNone: "Nenhum gesto detetado",
        .gestureThumbsUp: "Fixe 👍",
        .gestureOpenPalm: "Mão aberta ✋",
        .gestureClosedFist: "Punho fechado ✊",
        .themeLight: "Claro",
        .themeDark: "Escuro",
        .themeSystem: "Sistema",
        .footerPrivacy: "Privacidade em primeiro lugar: o vídeo nunca sai do dispositivo.",
        .footerDevelopedBy: "Desenvolvido por",
    ],
    .english: [
        .appTitle: "Face AI ID",
        .appTagline: "Real-time gesture recognition",
        .splashDevelopedBy: "Developed by David Arsénio Martins",
        .heroTitle: "Gesture recognition",
        .heroSubtitle: "Point the camera and show your hand. Everything runs locally on-device.",
        .cameraStart: "Start camera",
        .cameraStop: "Stop camera",
        .cameraPermission: "Camera access permission is required.",
        .cameraError: "Could not access the camera.",
        .gestureNone: "No gesture detected",
        .gestureThumbsUp: "Thumbs up 👍",
        .gestureOpenPalm: "Open palm ✋",
        .gestureClosedFist: "Closed fist ✊",
        .themeLight: "Light",
        .themeDark: "Dark",
        .themeSystem: "System",
        .footerPrivacy: "Privacy first: video never leaves the device.",
        .footerDevelopedBy: "Developed by",
    ],
]

@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    private static let storageKey = "faceaiid.language"

    @Published public var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey) }
    }

    private init() {
        if let stored = UserDefaults.standard.string(forKey: Self.storageKey),
           let language = AppLanguage(rawValue: stored) {
            self.language = language
        } else {
            let preferred = Locale.preferredLanguages.first ?? "en"
            self.language = preferred.hasPrefix("pt") ? .portuguese : .english
        }
    }

    public func string(_ key: LocalizedKey) -> String {
        strings[language]?[key] ?? key.rawValue
    }
}
