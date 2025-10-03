//
//  SiplyApp.swift
//  Siply
//
//  Created by Jonas Hoppe on 27.09.25.
//

import SwiftUI

@main
struct SiplyApp: App {
    @State private var addWaterAmount: Int? = nil

    var body: some Scene {
        WindowGroup {
            ContentView(addWaterAmount: $addWaterAmount)
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }

    private func handleURL(_ url: URL) {
        print("🔗 Received URL: \(url.absoluteString)")
        print("🔗 Scheme: \(url.scheme ?? "nil"), Host: \(url.host ?? "nil")")

        guard url.scheme == "siply",
              url.host == "addwater",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let amountString = components.queryItems?.first(where: { $0.name == "amount" })?.value,
              let amount = Int(amountString) else {
            print("❌ Failed to parse URL")
            return
        }

        print("✅ Adding \(amount)ml from URL")
        addWaterAmount = amount
    }
}
