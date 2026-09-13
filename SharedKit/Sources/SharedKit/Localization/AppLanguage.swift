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
    case heroSubtitle
    case cameraStart
    case cameraStop
    case cameraPermission
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
    case handLeft
    case handRight
    case footerPrivacy
    case footerDevelopedBy
    case modeHands
    case modeFace
    case heroSubtitleFace
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
    case faceIdSampleSaved
    case faceIdUnknown
    case faceIdPrivacyNote
}

private let strings: [AppLanguage: [LocalizedKey: String]] = [
    .portuguese: [
        .appTitle: "Face AI ID",
        .appTagline: "Reconhecimento de gestos em tempo real",
        .splashDevelopedBy: "Criado por David Arsénio Martins",
        .heroSubtitle: "Aponta a câmara e mostra a mão. Tudo é processado localmente no dispositivo.",
        .cameraStart: "Iniciar câmara",
        .cameraStop: "Parar câmara",
        .cameraPermission: "É necessário dar permissão de acesso à câmara.",
        .cameraDenied: "Permissão de câmara recusada. Ativa-a em Definições do Sistema → Privacidade e Segurança → Câmara.",
        .cameraError: "Não foi possível aceder à câmara.",
        .gestureNone: "Nenhum gesto detetado",
        .gestureThumbsUp: "Fixe 👍",
        .gestureOpenPalm: "Mão aberta ✋",
        .gestureClosedFist: "Punho fechado ✊",
        .gesturePeaceSign: "Sinal de paz ✌️",
        .gesturePointing: "A apontar ☝️",
        .gestureThumbsDown: "Não gostei 👎",
        .gestureThreeFingers: "Três dedos (W) 🤟",
        .gestureShaka: "Shaka 🤙",
        .gestureILoveYou: "Amo-te (LGP/ASL) 🤟",
        .gestureLetterA: "Letra A (LGP/ASL) ✊",
        .gestureLetterD: "Letra D (LGP/ASL) ☝️",
        .gestureLetterF: "Letra F (LGP/ASL) 👌",
        .gestureLetterI: "Letra I (LGP/ASL) 🤙",
        .gestureLetterL: "Letra L (LGP/ASL) 👆",
        .gestureLetterO: "Letra O (LGP/ASL) 👌",
        .gestureRockOn: "Rock on 🤘",
        .handLeft: "Mão esquerda",
        .handRight: "Mão direita",
        .footerPrivacy: "Privacidade em primeiro lugar: o vídeo nunca sai do dispositivo.",
        .footerDevelopedBy: "Desenvolvido por",
        .modeHands: "Mãos",
        .modeFace: "Rosto",
        .heroSubtitleFace: "Aponta a câmara à tua cara. Deteta sorriso, tristeza, surpresa, zanga, piscar e movimento de cabeça.",
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
        .faceIdSampleSaved: "Amostra guardada",
        .faceIdUnknown: "Rosto não reconhecido",
        .faceIdPrivacyNote: "Identificação aproximada, guardada só neste dispositivo — nunca enviada para nenhum servidor.",
    ],
    .english: [
        .appTitle: "Face AI ID",
        .appTagline: "Real-time gesture recognition",
        .splashDevelopedBy: "Developed by David Arsénio Martins",
        .heroSubtitle: "Point the camera and show your hand. Everything runs locally on-device.",
        .cameraStart: "Start camera",
        .cameraStop: "Stop camera",
        .cameraPermission: "Camera access permission is required.",
        .cameraDenied: "Camera permission was denied. Enable it in System Settings → Privacy & Security → Camera.",
        .cameraError: "Could not access the camera.",
        .gestureNone: "No gesture detected",
        .gestureThumbsUp: "Thumbs up 👍",
        .gestureOpenPalm: "Open palm ✋",
        .gestureClosedFist: "Closed fist ✊",
        .gesturePeaceSign: "Peace sign ✌️",
        .gesturePointing: "Pointing ☝️",
        .gestureThumbsDown: "Thumbs down 👎",
        .gestureThreeFingers: "Three fingers (W) 🤟",
        .gestureShaka: "Shaka 🤙",
        .gestureILoveYou: "I love you (ASL/LGP) 🤟",
        .gestureLetterA: "Letter A (ASL/LGP) ✊",
        .gestureLetterD: "Letter D (ASL/LGP) ☝️",
        .gestureLetterF: "Letter F (ASL/LGP) 👌",
        .gestureLetterI: "Letter I (ASL/LGP) 🤙",
        .gestureLetterL: "Letter L (ASL/LGP) 👆",
        .gestureLetterO: "Letter O (ASL/LGP) 👌",
        .gestureRockOn: "Rock on 🤘",
        .handLeft: "Left hand",
        .handRight: "Right hand",
        .footerPrivacy: "Privacy first: video never leaves the device.",
        .footerDevelopedBy: "Developed by",
        .modeHands: "Hands",
        .modeFace: "Face",
        .heroSubtitleFace: "Point the camera at your face. Detects smile, sadness, surprise, anger, blinking and head movement.",
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
        .faceIdSampleSaved: "Sample saved",
        .faceIdUnknown: "Face not recognized",
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
