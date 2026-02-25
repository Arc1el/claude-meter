import Foundation
import Combine

class LanguageManager: ObservableObject {
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "appLanguage") }
    }

    init() {
        language = UserDefaults.standard.string(forKey: "appLanguage") ?? "ko"
    }

    var isKorean: Bool { language == "ko" }

    /// 한국어면 ko, 영어면 en 반환
    func s(_ ko: String, _ en: String) -> String { isKorean ? ko : en }

    func toggle() { language = isKorean ? "en" : "ko" }
}
