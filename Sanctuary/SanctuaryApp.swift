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
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(AppTheme.tabBackground)
        appearance.shadowColor = UIColor(AppTheme.tabBorder)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppTheme.tabActive)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.tabActive)
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppTheme.tabInactive)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.tabInactive)
        ]

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
