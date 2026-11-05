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

public enum LocalizedKey: String, Sendable {
    case appTitle
    case appTagline
    case splashDevelopedBy
    case heroSubtitleUnified
    case cameraCancel
    case cameraStarting
    case cameraReady
    case cameraUnavailable
    case cameraOpenSettings
    case faceIdRegistrationFailed
    case cameraStart
    case cameraStop
    case cameraDenied
    case cameraError
    case gestureNone
    case gestureThumbsUp
    case gestureOpenPalm
    case gestureClosedFist
    case gesturePeaceSign
    case gesturePointing
    case gestureThumbsDown
    case gestureThreeFingers
    case gestureShaka
    case gestureILoveYou
    case gestureLetterA
    case gestureLetterD
    case gestureLetterF
    case gestureLetterI
    case gestureLetterL
    case gestureLetterO
    case gestureRockOn
    case gestureLetterB
    case gestureLetterU
    case gestureFingersCrossed
    case handLeft
    case handRight
    case footerPrivacy
    case footerDevelopedBy
    case expressionNone
    case expressionSmile
    case expressionSad
    case expressionSurprised
    case expressionAngry
    case expressionBlink
    case expressionLaugh
    case expressionKiss
    case expressionMouthOpen
    case expressionBrowsRaised
    case expressionWink
    case headNone
    case headNodYes
    case headShakeNo
    case headTilt
    case headTurnLeft
    case headTurnRight
    case headLookUp
    case headLookDown
    case faceIdNamePlaceholder
    case faceIdRegister
    case faceIdNoFaceDetected
    case faceIdSampleSaved
    case faceIdUnknown
    case faceIdRemove
    case faceIdLowQuality
    case languageLabel
    case themeLabel
    case themeLight
    case themeDark
    case themeSystem
    case debugShow
    case debugHide
    case faceIdPrivacyNote
}

#if os(iOS)
private let cameraDeniedPT = "Permissão de câmara recusada. Ativa-a em Definições → Face AI ID → Câmara."
private let cameraDeniedEN = "Camera permission was denied. Enable it in Settings → Face AI ID → Camera."
#else
private let cameraDeniedPT = "Permissão de câmara recusada. Ativa-a em Definições do Sistema → Privacidade e Segurança → Câmara."
private let cameraDeniedEN = "Camera permission was denied. Enable it in System Settings → Privacy & Security → Camera."
#endif

private let strings: [AppLanguage: [LocalizedKey: String]] = [
    .portuguese: [
        .appTitle: "Face AI ID",
        .appTagline: "Reconhecimento de gestos em tempo real",
        .splashDevelopedBy: "Criado por David Arsénio Martins",
        .heroSubtitleUnified: "Aponta a câmara à tua mão e à tua cara. Deteta gestos, expressões, movimento de cabeça e reconhece quem és — tudo ao mesmo tempo, processado localmente no dispositivo.",
        .cameraCancel: "Cancelar arranque",
        .cameraStarting: "A iniciar a câmara…",
        .cameraReady: "Pronto para começar. Carrega em Iniciar câmara.",
        .cameraUnavailable: "Não foi encontrada nenhuma câmara. Liga uma câmara e tenta novamente.",
        .cameraOpenSettings: "Abrir definições de câmara",
        .faceIdRegistrationFailed: "Não foi possível guardar este rosto. Tenta novamente com boa iluminação.",
        .cameraStart: "Iniciar câmara",
        .cameraStop: "Parar câmara",
        .cameraDenied: cameraDeniedPT,
        .cameraError: "Não foi possível aceder à câmara.",
        .gestureNone: "Nenhum gesto detetado",
        .gestureThumbsUp: "Fixe 👍",
        .gestureOpenPalm: "Mão aberta ✋",
        .gestureClosedFist: "Punho fechado ✊",
        .gesturePeaceSign: "Sinal de paz ✌️",
        .gesturePointing: "A apontar ☝️",
        .gestureThumbsDown: "Não gostei 👎",
        .gestureThreeFingers: "Três dedos (W) 🤟",
        .gestureShaka: "Shaka / Letra Y 🤙",
        .gestureILoveYou: "Amo-te (LGP/ASL) 🤟",
        .gestureLetterA: "Letra A (LGP/ASL) ✊",
        .gestureLetterD: "Letra D (LGP/ASL) ☝️",
        .gestureLetterF: "OK / Letra F 👌",
        .gestureLetterI: "Letra I (LGP/ASL) 🤙",
        .gestureLetterL: "Letra L (LGP/ASL) 👆",
        .gestureLetterO: "Letra O (LGP/ASL) 👌",
        .gestureRockOn: "Rock on 🤘",
        .gestureLetterB: "Letra B / Quatro (LGP/ASL) 🖐️",
        .gestureLetterU: "Letra U (LGP/ASL) 🤞",
        .gestureFingersCrossed: "Dedos cruzados 🤞",
        .handLeft: "Mão esquerda",
        .handRight: "Mão direita",
        .footerPrivacy: "Privacidade em primeiro lugar: o vídeo nunca sai do dispositivo.",
        .footerDevelopedBy: "Desenvolvido por",
        .expressionNone: "Nenhuma expressão detetada",
        .expressionSmile: "A sorrir 😊",
        .expressionSad: "Triste 😢",
        .expressionSurprised: "Surpreso(a) 😲",
        .expressionAngry: "Zangado(a) 😠",
        .expressionBlink: "Olhos fechados 😌",
        .expressionLaugh: "A rir 😄",
        .expressionKiss: "Beijinho 😘",
        .expressionMouthOpen: "Boca aberta 😮",
        .expressionBrowsRaised: "Sobrancelhas levantadas 🤨",
        .expressionWink: "A piscar o olho 😉",
        .headNone: "Sem movimento detetado",
        .headNodYes: "A acenar que sim 👍",
        .headShakeNo: "A acenar que não 👎",
        .headTilt: "Cabeça inclinada",
        .headTurnLeft: "A olhar para a esquerda ⬅️",
        .headTurnRight: "A olhar para a direita ➡️",
        .headLookUp: "A olhar para cima ⬆️",
        .headLookDown: "A olhar para baixo ⬇️",
        .faceIdNamePlaceholder: "Nome da pessoa",
        .faceIdRegister: "Registar rosto",
        .faceIdNoFaceDetected: "Nenhum rosto detetado.",
        .faceIdSampleSaved: "Amostra guardada",
        .faceIdUnknown: "Rosto não reconhecido",
        .faceIdRemove: "Remover",
        .faceIdLowQuality: "Imagem pouco nítida. Olha de frente para a câmara, aproxima-te e tenta outra vez.",
        .languageLabel: "Idioma",
        .themeLabel: "Aspeto",
        .themeLight: "Claro",
        .themeDark: "Escuro",
        .themeSystem: "Sistema",
        .debugShow: "Mostrar números de diagnóstico",
        .debugHide: "Esconder números de diagnóstico",
        .faceIdPrivacyNote: "Identificação aproximada, guardada só neste dispositivo — nunca enviada para nenhum servidor.",
    ],
    .english: [
        .appTitle: "Face AI ID",
        .appTagline: "Real-time gesture recognition",
        .splashDevelopedBy: "Developed by David Arsénio Martins",
        .heroSubtitleUnified: "Point the camera at your hand and your face. Detects gestures, expressions, head movement and recognizes who you are — all at once, processed locally on-device.",
        .cameraCancel: "Cancel startup",
        .cameraStarting: "Starting camera…",
        .cameraReady: "Ready when you are. Press Start camera.",
        .cameraUnavailable: "No camera found. Connect a camera and try again.",
        .cameraOpenSettings: "Open camera settings",
        .faceIdRegistrationFailed: "Could not save this face. Try again with good lighting.",
        .cameraStart: "Start camera",
        .cameraStop: "Stop camera",
        .cameraDenied: cameraDeniedEN,
        .cameraError: "Could not access the camera.",
        .gestureNone: "No gesture detected",
        .gestureThumbsUp: "Thumbs up 👍",
        .gestureOpenPalm: "Open palm ✋",
        .gestureClosedFist: "Closed fist ✊",
        .gesturePeaceSign: "Peace sign ✌️",
        .gesturePointing: "Pointing ☝️",
        .gestureThumbsDown: "Thumbs down 👎",
        .gestureThreeFingers: "Three fingers (W) 🤟",
        .gestureShaka: "Shaka / Letter Y 🤙",
        .gestureILoveYou: "I love you (ASL/LGP) 🤟",
        .gestureLetterA: "Letter A (ASL/LGP) ✊",
        .gestureLetterD: "Letter D (ASL/LGP) ☝️",
        .gestureLetterF: "OK / Letter F 👌",
        .gestureLetterI: "Letter I (ASL/LGP) 🤙",
        .gestureLetterL: "Letter L (ASL/LGP) 👆",
        .gestureLetterO: "Letter O (ASL/LGP) 👌",
        .gestureRockOn: "Rock on 🤘",
        .gestureLetterB: "Letter B / Four (ASL/LGP) 🖐️",
        .gestureLetterU: "Letter U (ASL/LGP) 🤞",
        .gestureFingersCrossed: "Fingers crossed 🤞",
        .handLeft: "Left hand",
        .handRight: "Right hand",
        .footerPrivacy: "Privacy first: video never leaves the device.",
        .footerDevelopedBy: "Developed by",
        .expressionNone: "No expression detected",
        .expressionSmile: "Smiling 😊",
        .expressionSad: "Sad 😢",
        .expressionSurprised: "Surprised 😲",
        .expressionAngry: "Angry 😠",
        .expressionBlink: "Eyes closed 😌",
        .expressionLaugh: "Laughing 😄",
        .expressionKiss: "Kiss 😘",
        .expressionMouthOpen: "Mouth open 😮",
        .expressionBrowsRaised: "Eyebrows raised 🤨",
        .expressionWink: "Winking 😉",
        .headNone: "No movement detected",
        .headNodYes: "Nodding yes 👍",
        .headShakeNo: "Shaking no 👎",
        .headTilt: "Head tilted",
        .headTurnLeft: "Looking left ⬅️",
        .headTurnRight: "Looking right ➡️",
        .headLookUp: "Looking up ⬆️",
        .headLookDown: "Looking down ⬇️",
        .faceIdNamePlaceholder: "Person's name",
        .faceIdRegister: "Register face",
        .faceIdNoFaceDetected: "No face detected.",
        .faceIdSampleSaved: "Sample saved",
        .faceIdUnknown: "Face not recognized",
        .faceIdRemove: "Remove",
        .faceIdLowQuality: "Image not clear enough. Face the camera, move closer and try again.",
        .languageLabel: "Language",
        .themeLabel: "Appearance",
        .themeLight: "Light",
        .themeDark: "Dark",
        .themeSystem: "System",
        .debugShow: "Show diagnostic numbers",
        .debugHide: "Hide diagnostic numbers",
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
