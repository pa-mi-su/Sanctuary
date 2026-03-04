import SwiftUI

enum AppTab: Hashable {
    case home
    case novenas
    case liturgical
    case saints
    case me
}

struct AppShellView: View {
    let environment: AppEnvironment
    @State private var selectedTab: AppTab = .home
    @StateObject private var localization = LocalizationManager()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tag(AppTab.home)
                .tabItem {
                    Label(localization.t("tab.home"), systemImage: "house.fill")
                }

            NovenasCalendarView(environment: environment)
                .tag(AppTab.novenas)
                .tabItem {
                    Label(localization.t("tab.novenas"), systemImage: "book.fill")
                }

            LiturgicalCalendarView(environment: environment)
                .tag(AppTab.liturgical)
                .tabItem {
                    Label(localization.t("tab.liturgical"), systemImage: "calendar")
                }

            SaintsCalendarView(environment: environment)
                .tag(AppTab.saints)
                .tabItem {
                    Label(localization.t("tab.saints"), systemImage: "person.3.fill")
                }

            MeView(environment: environment)
                .tag(AppTab.me)
                .tabItem {
                    Label(localization.t("tab.me"), systemImage: "person.circle.fill")
                }
        }
        .tint(AppTheme.tabActive)
        .environmentObject(localization)
    }
}

struct AppShellView_Previews: PreviewProvider {
    static var previews: some View {
        AppShellView(environment: .local())
    }
}
