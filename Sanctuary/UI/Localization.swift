import Foundation
import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case es
    case pl

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .es: return "Spanish"
        case .pl: return "Polish"
        }
    }

    var contentLocale: ContentLocale {
        switch self {
        case .en: return .en
        case .es: return .es
        case .pl: return .pl
        }
    }
}

@MainActor
final class LocalizationManager: ObservableObject {
    @Published var language: AppLanguage = .en

    func t(_ key: String) -> String {
        switch language {
        case .en: return LocalizationManager.english[key] ?? key
        case .es: return LocalizationManager.spanish[key] ?? LocalizationManager.english[key] ?? key
        case .pl: return LocalizationManager.polish[key] ?? LocalizationManager.english[key] ?? key
        }
    }

    private static let english: [String: String] = [
        "tab.home": "Home",
        "tab.novenas": "Novenas",
        "tab.liturgical": "Liturgical",
        "tab.saints": "Saints",
        "tab.me": "Me",
        "home.about": "About Sanctuary",
        "home.language": "Language",
        "home.welcome": "Welcome to your sanctuary",
        "home.connect": "How do you want to connect with God?",
        "home.saints": "Saints",
        "home.prayers": "Prayers",
        "home.daily": "Daily Reading",
        "home.intentions": "Intentions",
        "home.parish": "Find My Local Parish",
        "home.chooseLanguage": "Choose language",
        "common.close": "Close",
        "about.title": "About • Sanctuary",
        "about.subtitle": "A simple, focused Catholic companion: liturgical seasons, saints, and novenas — with daily readings one tap away.",
        "about.whatsInApp": "What's in the app",
        "about.references": "References",
        "about.contact": "Contact & feedback",
        "calendar.today": "Today",
        "calendar.day": "Day",
        "calendar.week": "Week",
        "calendar.month": "Month",
        "calendar.search": "Search",
        "calendar.searchSaints": "Search Saints",
        "calendar.searchNovenas": "Search Novenas",
        "calendar.searchIntentions": "Search Novena Intentions",
        "me.subtitle": "Your novenas in progress and saved favorites.",
        "me.inProgress": "Novenas in Progress",
        "me.favoriteNovenas": "Favorite Novenas",
        "me.favoriteSaints": "Favorite Saints"
    ]

    private static let spanish: [String: String] = [
        "tab.home": "Inicio",
        "tab.novenas": "Novenas",
        "tab.liturgical": "Litúrgico",
        "tab.saints": "Santos",
        "tab.me": "Yo",
        "home.about": "Acerca de Sanctuary",
        "home.language": "Idioma",
        "home.welcome": "Bienvenido a tu santuario",
        "home.connect": "¿Cómo quieres conectarte con Dios?",
        "home.saints": "Santos",
        "home.prayers": "Oraciones",
        "home.daily": "Lectura diaria",
        "home.intentions": "Intenciones",
        "home.parish": "Encontrar mi parroquia local",
        "home.chooseLanguage": "Elegir idioma",
        "common.close": "Cerrar",
        "about.title": "Acerca de • Sanctuary",
        "about.references": "Referencias",
        "about.contact": "Contacto y comentarios",
        "calendar.today": "Hoy",
        "calendar.day": "Día",
        "calendar.week": "Semana",
        "calendar.month": "Mes",
        "calendar.search": "Buscar",
        "calendar.searchSaints": "Buscar santos",
        "calendar.searchNovenas": "Buscar novenas",
        "calendar.searchIntentions": "Buscar intenciones de novena",
        "me.subtitle": "Tus novenas en curso y favoritos guardados.",
        "me.inProgress": "Novenas en curso",
        "me.favoriteNovenas": "Novenas favoritas",
        "me.favoriteSaints": "Santos favoritos"
    ]

    private static let polish: [String: String] = [
        "tab.home": "Strona główna",
        "tab.novenas": "Nowenny",
        "tab.liturgical": "Liturgiczny",
        "tab.saints": "Święci",
        "tab.me": "Ja",
        "home.about": "O Sanctuary",
        "home.language": "Język",
        "home.welcome": "Witamy w twoim sanktuarium",
        "home.connect": "Jak chcesz połączyć się z Bogiem?",
        "home.saints": "Święci",
        "home.prayers": "Modlitwy",
        "home.daily": "Czytanie dnia",
        "home.intentions": "Intencje",
        "home.parish": "Znajdź moją parafię",
        "home.chooseLanguage": "Wybierz język",
        "common.close": "Zamknij",
        "about.title": "O aplikacji • Sanctuary",
        "about.references": "Źródła",
        "about.contact": "Kontakt i opinie",
        "calendar.today": "Dzisiaj",
        "calendar.day": "Dzień",
        "calendar.week": "Tydzień",
        "calendar.month": "Miesiąc",
        "calendar.search": "Szukaj",
        "calendar.searchSaints": "Szukaj świętych",
        "calendar.searchNovenas": "Szukaj nowenn",
        "calendar.searchIntentions": "Szukaj intencji nowenny",
        "me.subtitle": "Twoje trwające nowenny i zapisane ulubione.",
        "me.inProgress": "Nowenny w trakcie",
        "me.favoriteNovenas": "Ulubione nowenny",
        "me.favoriteSaints": "Ulubieni święci"
    ]
}
