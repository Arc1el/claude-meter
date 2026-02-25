import Foundation
import Combine

class LanguageManager: ObservableObject {
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "appLanguage") }
    }

    init() {
        language = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
    }

    var isKorean: Bool { language == "ko" }

    var locale: Locale { Locale(identifier: isKorean ? "ko_KR" : "en_US") }

    func s(_ ko: String, _ en: String) -> String { isKorean ? ko : en }

    func toggle() { language = isKorean ? "en" : "ko" }
}
