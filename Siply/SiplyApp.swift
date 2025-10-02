//
//  SiplyApp.swift
//  Siply
//
//  Created by Jonas Hoppe on 27.09.25.
//

import SwiftUI

@main
struct SiplyApp: App {
    init() {
        // Set app language based on device locale
        LanguageManager.shared.setAppLanguage()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
