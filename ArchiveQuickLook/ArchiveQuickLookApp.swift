//
//  ArchiveQuickLookApp.swift
//  ArchiveQuickLook
//
//  Created by Michal Šára on 16.11.2025.
//

import SwiftUI

@main
struct ArchiveQuickLookApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .navigationTitle(appVersion)
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "x.x"
        return "ArchiveQuickLook v\(version)"
    }
}
