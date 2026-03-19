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
    @StateObject private var localization: LocalizationManager
    @StateObject private var progressStore: UserProgressStore

    init(environment: AppEnvironment) {
        self.environment = environment
        _localization = StateObject(wrappedValue: LocalizationManager())
        _progressStore = StateObject(
            wrappedValue: UserProgressStore(userProgressRepository: environment.userProgressRepository)
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(environment: environment)
                .tag(AppTab.home)
                .tabItem {
                    Label(localization.t("tab.home"), systemImage: "house.fill")
                }

            LazyTabContent(activeTab: $selectedTab, tab: .novenas) {
                NovenasCalendarView(environment: environment)
            }
                .tag(AppTab.novenas)
                .tabItem {
                    Label(localization.t("tab.novenas"), systemImage: "book.closed.fill")
                }

            LazyTabContent(activeTab: $selectedTab, tab: .liturgical) {
                LiturgicalCalendarView(environment: environment)
            }
                .tag(AppTab.liturgical)
                .tabItem {
                    Label(localization.t("tab.liturgical"), systemImage: "calendar.badge.clock")
                }

            LazyTabContent(activeTab: $selectedTab, tab: .saints) {
                SaintsCalendarView(environment: environment)
            }
                .tag(AppTab.saints)
                .tabItem {
                    Label(localization.t("tab.saints"), systemImage: "person.2.crop.square.stack.fill")
                }

            LazyTabContent(activeTab: $selectedTab, tab: .me) {
                MeView(environment: environment)
            }
                .tag(AppTab.me)
                .tabItem {
                    Label(localization.t("tab.me"), systemImage: "person.circle.fill")
                }
        }
        .tint(AppTheme.tabActive)
        .environmentObject(localization)
        .environmentObject(progressStore)
        .task {
            // Let first frame and taps land before background state refresh.
            try? await Task.sleep(nanoseconds: 700_000_000)
            await progressStore.refresh()
        }
    }
}

private struct LazyTabContent<Content: View>: View {
    @Binding var activeTab: AppTab
    let tab: AppTab
    let content: () -> Content
    @State private var loaded = false

    var body: some View {
        Group {
            if loaded || activeTab == tab {
                content()
                    .onAppear { loaded = true }
            } else {
                Color.clear
            }
        }
    }
}

struct AppShellView_Previews: PreviewProvider {
    static var previews: some View {
        AppShellView(environment: .local())
    }
}
