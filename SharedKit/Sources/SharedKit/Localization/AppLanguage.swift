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
    case gesturePeaceSign
    case gesturePointing
    case themeLight
    case themeDark
    case themeSystem
    case footerPrivacy
    case footerDevelopedBy
    case modeHands
    case modeFace
    case modeFaceId
    case heroTitleFace
    case heroSubtitleFace
    case heroTitleFaceId
    case heroSubtitleFaceId
    case expressionNone
    case expressionSmile
    case expressionSad
    case expressionSurprised
    case expressionAngry
    case expressionBlink
    case headNone
    case headNodYes
    case headShakeNo
    case headTilt
    case faceIdNamePlaceholder
    case faceIdRegister
    case faceIdNoFaceDetected
    case faceIdUnknown
    case faceIdRemove
    case faceIdPrivacyNote
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
        .gesturePeaceSign: "Sinal de paz ✌️",
        .gesturePointing: "A apontar ☝️",
        .themeLight: "Claro",
        .themeDark: "Escuro",
        .themeSystem: "Sistema",
        .footerPrivacy: "Privacidade em primeiro lugar: o vídeo nunca sai do dispositivo.",
        .footerDevelopedBy: "Desenvolvido por",
        .modeHands: "Mãos",
        .modeFace: "Rosto",
        .modeFaceId: "Identificação",
        .heroTitleFace: "Expressões e movimento de cabeça",
        .heroSubtitleFace: "Aponta a câmara à tua cara. Deteta sorriso, tristeza, surpresa, zanga, piscar e movimento de cabeça.",
        .heroTitleFaceId: "Identificação facial",
        .heroSubtitleFaceId: "Regista a tua cara e a app reconhece-te depois. Guardado só neste dispositivo.",
        .expressionNone: "Nenhuma expressão detetada",
        .expressionSmile: "A sorrir 😊",
        .expressionSad: "Triste 😢",
        .expressionSurprised: "Surpreso(a) 😲",
        .expressionAngry: "Zangado(a) 😠",
        .expressionBlink: "A piscar 😉",
        .headNone: "Sem movimento detetado",
        .headNodYes: "A acenar que sim 👍",
        .headShakeNo: "A acenar que não 👎",
        .headTilt: "Cabeça inclinada",
        .faceIdNamePlaceholder: "Nome da pessoa",
        .faceIdRegister: "Registar rosto",
        .faceIdNoFaceDetected: "Nenhum rosto detetado.",
        .faceIdUnknown: "Rosto não reconhecido",
        .faceIdRemove: "Remover",
        .faceIdPrivacyNote: "Identificação aproximada, guardada só neste dispositivo — nunca enviada para nenhum servidor.",
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
        .gesturePeaceSign: "Peace sign ✌️",
        .gesturePointing: "Pointing ☝️",
        .themeLight: "Light",
        .themeDark: "Dark",
        .themeSystem: "System",
        .footerPrivacy: "Privacy first: video never leaves the device.",
        .footerDevelopedBy: "Developed by",
        .modeHands: "Hands",
        .modeFace: "Face",
        .modeFaceId: "Identification",
        .heroTitleFace: "Expressions and head movement",
        .heroSubtitleFace: "Point the camera at your face. Detects smile, sadness, surprise, anger, blinking and head movement.",
        .heroTitleFaceId: "Face identification",
        .heroSubtitleFaceId: "Register your face and the app will recognize you afterwards. Stored only on this device.",
        .expressionNone: "No expression detected",
        .expressionSmile: "Smiling 😊",
        .expressionSad: "Sad 😢",
        .expressionSurprised: "Surprised 😲",
        .expressionAngry: "Angry 😠",
        .expressionBlink: "Blinking 😉",
        .headNone: "No movement detected",
        .headNodYes: "Nodding yes 👍",
        .headShakeNo: "Shaking no 👎",
        .headTilt: "Head tilted",
        .faceIdNamePlaceholder: "Person's name",
        .faceIdRegister: "Register face",
        .faceIdNoFaceDetected: "No face detected.",
        .faceIdUnknown: "Face not recognized",
        .faceIdRemove: "Remove",
        .faceIdPrivacyNote: "Approximate identification, stored only on this device — never sent to any server.",
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
