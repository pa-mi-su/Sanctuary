import SwiftUI

enum NovenaSearchMode {
    case standard
    case intentions
}

struct SaintsSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @StateObject private var viewModel: SaintsListViewModel

    init(environment: AppEnvironment) {
        _viewModel = StateObject(
            wrappedValue: SaintsListViewModel(
                useCase: ListSaintsUseCase(contentRepository: environment.contentRepository)
            )
        )
    }

    var body: some View {
        NavigationStack {
            List(viewModel.saints) { saint in
                NavigationLink {
                    SaintDetailView(saint: saint)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.displayName(for: saint)).font(.headline)
                        Text(viewModel.summary(for: saint))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .searchable(text: $viewModel.query, prompt: localization.t("search.saintsPrompt"))
            .onSubmit(of: .search) { Task { await viewModel.search() } }
            .task {
                viewModel.setLocale(localization.language.contentLocale)
                await viewModel.load()
            }
            .onChange(of: localization.language) { newValue in
                Task {
                    viewModel.setLocale(newValue.contentLocale)
                    await viewModel.load()
                }
            }
            .navigationTitle(localization.t("search.saintsTitle"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.t("common.close")) { dismiss() }
                }
            }
        }
    }
}

struct NovenasSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @StateObject private var viewModel: NovenasListViewModel
    let mode: NovenaSearchMode
    @State private var intentionsQuery = ""
    @State private var intentionItems: [IntentionSearchItem] = []

    init(environment: AppEnvironment, mode: NovenaSearchMode = .standard) {
        self.mode = mode
        _viewModel = StateObject(
            wrappedValue: NovenasListViewModel(
                useCase: ListNovenasUseCase(contentRepository: environment.contentRepository)
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if mode == .intentions {
                    List(filteredIntentionItems) { item in
                        NavigationLink {
                            NovenaDetailView(novena: item.novena)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title).font(.headline)
                                Text(localization.t("search.novenaType"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Divider()
                                Text("\(localization.t("search.intentionsLabel")): \(item.intentions.joined(separator: ", "))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                    }
                    .searchable(text: $intentionsQuery, prompt: localization.t("search.intentionsPrompt"))
                } else {
                    List(viewModel.novenas) { novena in
                        NavigationLink {
                            NovenaDetailView(novena: novena)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.title(for: novena)).font(.headline)
                                Text(viewModel.summary(for: novena))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .searchable(text: $viewModel.query, prompt: localization.t("search.novenasPrompt"))
                    .onSubmit(of: .search) { Task { await viewModel.search() } }
                }
            }
            .task {
                viewModel.setLocale(localization.language.contentLocale)
                await viewModel.load()
                if mode == .intentions {
                    rebuildIntentionItems()
                }
            }
            .onChange(of: localization.language) { newValue in
                Task {
                    viewModel.setLocale(newValue.contentLocale)
                    await viewModel.load()
                    if mode == .intentions {
                        rebuildIntentionItems()
                    }
                }
            }
            .navigationTitle(mode == .intentions ? localization.t("calendar.searchIntentions") : localization.t("search.novenasTitle"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.t("common.close")) { dismiss() }
                }
            }
        }
    }

    private var filteredIntentionItems: [IntentionSearchItem] {
        let q = normalized(intentionsQuery)
        guard !q.isEmpty else { return intentionItems }
        return intentionItems.filter { $0.searchBlob.contains(q) }
    }

    private func rebuildIntentionItems() {
        let locale = localization.language.contentLocale
        intentionItems = viewModel.novenas.compactMap { novena in
            guard let doc = ContentStore.novena(id: novena.id) else { return nil }
            let baseIntentions = (doc.intentions ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let rawIntentions = localizedIntentions(doc: doc, locale: locale)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !rawIntentions.isEmpty else { return nil }
            let intentions = rawIntentions.map(humanizeIntention)

            let title = viewModel.title(for: novena)
            let searchBlob = normalized(
                "\(title) \(novena.slug) \((novena.tags).joined(separator: " ")) \(baseIntentions.joined(separator: " ")) \(rawIntentions.joined(separator: " ")) \(intentions.joined(separator: " "))"
            )
            return IntentionSearchItem(
                id: novena.id,
                novena: novena,
                title: title,
                intentions: intentions,
                searchBlob: searchBlob
            )
        }
    }

    private func localizedIntentions(doc: NovenaDocument, locale: ContentLocale) -> [String] {
        switch locale {
        case .en:
            return doc.intentions ?? doc.intentions_es ?? doc.intentions_pl ?? []
        case .es:
            if let es = doc.intentions_es, !es.isEmpty { return es }
            if let en = doc.intentions, !en.isEmpty { return en.map { autoTranslateIntention($0, to: .es) } }
            return doc.intentions_pl ?? []
        case .pl:
            if let pl = doc.intentions_pl, !pl.isEmpty { return pl }
            if let en = doc.intentions, !en.isEmpty { return en.map { autoTranslateIntention($0, to: .pl) } }
            return doc.intentions_es ?? []
        }
    }

    private func autoTranslateIntention(_ value: String, to locale: ContentLocale) -> String {
        let text = humanizeIntention(value)
        guard locale != .en else { return text }

        let phraseMapES: [String: String] = [
            "married couples": "parejas casadas",
            "job seekers": "personas que buscan trabajo",
            "the unemployed": "personas desempleadas",
            "breast cancer patients": "pacientes con cáncer de mama",
            "mental illness": "enfermedad mental",
            "spiritual protection": "protección espiritual",
            "difficult marriages": "matrimonios difíciles",
            "young girls": "niñas jóvenes",
            "postal workers": "trabajadores postales",
            "telecommunication workers": "trabajadores de telecomunicaciones",
            "wild animals": "animales salvajes",
            "sick cattle": "ganado enfermo",
            "the poor": "los pobres",
            "wet nurses": "nodrizas",
            "rape victims": "víctimas de violación",
            "mothers": "madres",
            "housewives": "amas de casa",
            "fishermen": "pescadores",
            "singers": "cantantes",
            "musicians": "músicos",
            "the sick": "los enfermos",
            "mercy": "misericordia",
            "chastity": "castidad",
            "purity": "pureza",
            "travelers": "viajeros",
            "storms": "tormentas",
            "epilepsy": "epilepsia",
            "doctors": "doctores",
            "artists": "artistas",
            "farmers": "agricultores",
            "beekeepers": "apicultores",
            "printers": "impresores",
            "theologians": "teólogos",
            "students": "estudiantes",
            "kidney disease": "enfermedad renal",
            "poisoning": "envenenamiento",
            "illness": "enfermedad",
            "poverty": "pobreza",
            "france": "francia",
            "milan": "milán",
            "families": "familias",
            "carpenters": "carpinteros",
            "unmarried women": "mujeres solteras"
        ]

        let phraseMapPL: [String: String] = [
            "married couples": "małżeństwa",
            "job seekers": "osoby szukające pracy",
            "the unemployed": "osoby bezrobotne",
            "breast cancer patients": "pacjenci z rakiem piersi",
            "mental illness": "choroba psychiczna",
            "spiritual protection": "ochrona duchowa",
            "difficult marriages": "trudne małżeństwa",
            "young girls": "młode dziewczęta",
            "postal workers": "pracownicy poczty",
            "telecommunication workers": "pracownicy telekomunikacji",
            "wild animals": "dzikie zwierzęta",
            "sick cattle": "chore bydło",
            "the poor": "ubodzy",
            "wet nurses": "mamki",
            "rape victims": "ofiary gwałtu",
            "mothers": "matki",
            "housewives": "gospodynie domowe",
            "fishermen": "rybacy",
            "singers": "śpiewacy",
            "musicians": "muzycy",
            "the sick": "chorzy",
            "mercy": "miłosierdzie",
            "chastity": "czystość",
            "purity": "czystość",
            "travelers": "podróżni",
            "storms": "burze",
            "epilepsy": "padaczka",
            "doctors": "lekarze",
            "artists": "artyści",
            "farmers": "rolnicy",
            "beekeepers": "pszczelarze",
            "printers": "drukarze",
            "theologians": "teolodzy",
            "students": "uczniowie",
            "kidney disease": "choroba nerek",
            "poisoning": "zatrucie",
            "illness": "choroba",
            "poverty": "ubóstwo",
            "france": "francja",
            "milan": "mediolan",
            "families": "rodziny",
            "carpenters": "cieśle",
            "unmarried women": "niezamężne kobiety"
        ]

        let normalizedText = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        if locale == .es, let mapped = phraseMapES[normalizedText] { return mapped.capitalized(with: Locale(identifier: "es")) }
        if locale == .pl, let mapped = phraseMapPL[normalizedText] { return mapped.capitalized(with: Locale(identifier: "pl")) }
        return text
    }

    private func normalized(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func humanizeIntention(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return value }
        return cleaned.capitalized(with: .current)
    }
}

private struct IntentionSearchItem: Identifiable {
    let id: String
    let novena: Novena
    let title: String
    let intentions: [String]
    let searchBlob: String
}

struct GlobalSearchView: View {
    @EnvironmentObject private var localization: LocalizationManager
    let environment: AppEnvironment

    var body: some View {
        TabView {
            SaintsSearchView(environment: environment)
                .tabItem { Label(localization.t("tab.saints"), systemImage: "person.2") }
            NovenasSearchView(environment: environment)
                .tabItem { Label(localization.t("tab.novenas"), systemImage: "book") }
        }
    }
}
