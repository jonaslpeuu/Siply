//
//  LanguageManager.swift
//  Siply
//
//  Created by Claude on 02.10.25.
//

import Foundation

class LanguageManager {
    static let shared = LanguageManager()
    
    private init() {}
    
    /// Determines the app language based on device locale
    /// If device language is German, use German; otherwise use English
    func getAppLanguage() -> String {
        let deviceLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = String(deviceLanguage.prefix(2))
        
        return languageCode == "de" ? "de" : "en"
    }
    
    /// Sets the app language override
    func setAppLanguage() {
        let targetLanguage = getAppLanguage()
        
        // Set the language for the current session
        UserDefaults.standard.set([targetLanguage], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // Update bundle for immediate effect
        if let path = Bundle.main.path(forResource: targetLanguage, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            objc_setAssociatedObject(Bundle.main, &bundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// Bundle extension for runtime language switching
private var bundleKey: UInt8 = 0

extension Bundle {
    class var localizedBundle: Bundle {
        guard let bundle = objc_getAssociatedObject(Bundle.main, &bundleKey) as? Bundle else {
            return Bundle.main
        }
        return bundle
    }
}

// NSLocalizedString override
func LocalizedString(_ key: String, comment: String = "") -> String {
    return NSLocalizedString(key, bundle: Bundle.localizedBundle, comment: comment)
}