//
//  SanctuaryApp.swift
//  Sanctuary
//
//  Created by PMS on 3/3/26.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

@main
struct SanctuaryApp: App {
    private let environment = AppEnvironment.local()

    init() {
#if os(iOS)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.tabBackground)
        appearance.shadowColor = UIColor(AppTheme.tabBorder)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = UIColor(AppTheme.tabInactive)
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(environment: environment)
        }
    }
}
