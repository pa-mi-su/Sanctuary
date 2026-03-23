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
            ZStack {
                AppBackdrop()

                VStack(spacing: 14) {
                    SearchHeader(
                        title: localization.t("search.saintsTitle"),
                        dismiss: dismiss.callAsFunction
                    )

                    SearchField(
                        prompt: localization.t("search.saintsPrompt"),
                        text: $viewModel.query
                    ) {
                        Task { await viewModel.search() }
                    }

                    SearchResultsCount(count: viewModel.saints.count)

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.saints) { saint in
                                NavigationLink {
                                    SaintDetailView(saint: saint)
                                } label: {
                                    SearchResultCard(
                                        title: viewModel.displayName(for: saint),
                                        subtitle: viewModel.summary(for: saint),
                                        meta: "\(localization.t("saints.feastShort")): \(saint.feastMonth)/\(saint.feastDay)",
                                        accent: AppTheme.glowGold,
                                        icon: "person.fill"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .toolbar(.hidden, for: .navigationBar)
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
            .onChange(of: viewModel.query) { _ in
                Task { await viewModel.search() }
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
            ZStack {
                AppBackdrop()

                VStack(spacing: 14) {
                    SearchHeader(
                        title: mode == .intentions ? localization.t("calendar.searchIntentions") : localization.t("search.novenasTitle"),
                        dismiss: dismiss.callAsFunction
                    )

                    if mode == .intentions {
                        SearchField(
                            prompt: localization.t("search.intentionsPrompt"),
                            text: $intentionsQuery
                        )

                        SearchResultsCount(count: filteredIntentionItems.count)

                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredIntentionItems) { item in
                                    NavigationLink {
                                        NovenaDetailView(novena: item.novena)
                                    } label: {
                                        SearchResultCard(
                                            title: item.title,
                                            subtitle: item.intentions.joined(separator: ", "),
                                            meta: localization.t("search.intentionsLabel"),
                                            accent: AppTheme.glowRose,
                                            icon: "heart.text.square.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    } else {
                        SearchField(
                            prompt: localization.t("search.novenasPrompt"),
                            text: $viewModel.query
                        ) {
                            Task { await viewModel.search() }
                        }

                        SearchResultsCount(count: viewModel.novenas.count)

                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 10) {
                                ForEach(viewModel.novenas) { novena in
                                    NavigationLink {
                                        NovenaDetailView(novena: novena)
                                    } label: {
                                        SearchResultCard(
                                            title: viewModel.title(for: novena),
                                            subtitle: viewModel.summary(for: novena),
                                            meta: viewModel.dayText(for: novena),
                                            accent: AppTheme.glowBlue,
                                            icon: "book.closed.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .toolbar(.hidden, for: .navigationBar)
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
            .onChange(of: viewModel.query) { _ in
                guard mode == .standard else { return }
                Task { await viewModel.search() }
            }
        }
    }

    private var filteredIntentionItems: [IntentionSearchItem] {
        let q = normalized(intentionsQuery)
        guard !q.isEmpty else { return intentionItems }
        let rankedIDs = SearchMatcher.rankedIDs(for: q, in: intentionItems) { $0.document }
        let itemByID = Dictionary(uniqueKeysWithValues: intentionItems.map { ($0.id, $0) })
        return rankedIDs.compactMap { itemByID[$0] }
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
            let document = SearchMatcher.Document(
                itemID: novena.id,
                primaryText: title,
                secondaryText: "\(novena.slug) \((novena.tags).joined(separator: " "))",
                auxiliaryText: "\(baseIntentions.joined(separator: " ")) \(rawIntentions.joined(separator: " ")) \(intentions.joined(separator: " "))"
            )
            return IntentionSearchItem(
                id: novena.id,
                novena: novena,
                title: title,
                intentions: intentions,
                document: document
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
            "financial distress": "dificultades económicas",
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
            "and the children of mary": "y los hijos de maría",
            "learners": "estudiantes",
            "poor": "pobres",
            "fishermen": "pescadores",
            "singers": "cantantes",
            "brewers": "cerveceros",
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
            "students and europe": "estudiantes y europa",
            "kidney disease": "enfermedad renal",
            "poisoning": "envenenamiento",
            "illness": "enfermedad",
            "poverty": "pobreza",
            "france": "francia",
            "milan": "milán",
            "and lourdes": "y lourdes",
            "physicians": "médicos",
            "and of those with throat maladies": "y quienes padecen enfermedades de la garganta",
            "lebanon": "líbano",
            "sickness": "enfermedad",
            "holy death": "santa muerte",
            "eye disease": "enfermedades de los ojos",
            "television": "televisión",
            "laundry": "lavandería",
            "astronomers": "astrónomos",
            "dominican republic": "república dominicana",
            "falsely accused people": "personas acusadas falsamente",
            "choirboys": "monaguillos del coro",
            "the falsely accused": "los acusados falsamente",
            "incent victims": "víctimas de incesto",
            "messengers": "mensajeros",
            "pharmacists": "farmacéuticos",
            "paratroopers and parachutists": "paracaidistas y tropas aerotransportadas",
            "loss of parents": "pérdida de los padres",
            "those suffering back injury or back pain": "quienes sufren lesiones o dolor de espalda",
            "paris": "parís",
            "french security forces": "fuerzas de seguridad francesas",
            "england": "inglaterra",
            "and catalonia": "y cataluña",
            "the west indies": "las indias occidentales",
            "and unborn children": "y los niños no nacidos",
            "divorced people": "personas divorciadas",
            "of new discoveries": "de los nuevos descubrimientos",
            "fathers": "padres",
            "grandparents": "abuelos",
            "the ordinary opus dei": "el ordinario del opus dei",
            "the ordinary – opus dei": "el ordinario del opus dei",
            "families": "familias",
            "carpenters": "carpinteros",
            "unmarried women": "mujeres solteras",
            "hopeless cases": "casos desesperados",
            "desperate situations": "situaciones desesperadas",
            "rome": "roma",
            "chefs": "cocineros",
            "eye illness": "afecciones oculares",
            "money": "dinero",
            "bankers": "banqueros",
            "tax collectors": "recaudadores de impuestos",
            "wives": "esposas",
            "and abuse victims": "y víctimas de abuso",
            "civil defense volunteers": "voluntarios de defensa civil",
            "ireland": "irlanda",
            "engineers": "ingenieros",
            "cancer patient": "paciente con cáncer",
            "net makers": "fabricantes de redes",
            "and ship builders": "y constructores navales",
            "joy": "alegría",
            "usa forces": "fuerzas armadas de estados unidos",
            "babies": "bebés",
            "youth": "jóvenes",
            "impossible causes": "causas imposibles",
            "wounds": "heridas",
            "marital problems": "problemas matrimoniales",
            "nuns": "monjas",
            "against storms": "contra las tormentas",
            "against lightning": "contra los rayos",
            "against rain": "contra la lluvia",
            "soldiers": "soldados",
            "athletes": "atletas",
            "and those who desire a saintly": "y quienes desean una vida santa",
            "deacons": "diáconos",
            "altar servers": "monaguillos",
            "casket makers": "fabricantes de ataúdes"
        ]

        let phraseMapPL: [String: String] = [
            "financial distress": "trudności finansowe",
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
            "and the children of mary": "i dzieci maryi",
            "learners": "uczący się",
            "poor": "ubodzy",
            "fishermen": "rybacy",
            "singers": "śpiewacy",
            "brewers": "piwowarzy",
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
            "students and europe": "uczniowie i europa",
            "kidney disease": "choroba nerek",
            "poisoning": "zatrucie",
            "illness": "choroba",
            "poverty": "ubóstwo",
            "france": "francja",
            "milan": "mediolan",
            "and lourdes": "i lourdes",
            "physicians": "lekarze",
            "and of those with throat maladies": "i osoby cierpiące na choroby gardła",
            "lebanon": "liban",
            "sickness": "choroba",
            "holy death": "święta śmierć",
            "eye disease": "choroby oczu",
            "television": "telewizja",
            "laundry": "pralnictwo",
            "astronomers": "astronomowie",
            "dominican republic": "republika dominikańska",
            "falsely accused people": "osoby fałszywie oskarżone",
            "choirboys": "chłopcy z chóru",
            "the falsely accused": "fałszywie oskarżeni",
            "incent victims": "ofiary kazirodztwa",
            "messengers": "posłańcy",
            "pharmacists": "farmaceuci",
            "paratroopers and parachutists": "spadochroniarze i żołnierze wojsk powietrznodesantowych",
            "loss of parents": "utrata rodziców",
            "those suffering back injury or back pain": "cierpiący z powodu urazu lub bólu pleców",
            "paris": "paryż",
            "french security forces": "francuskie służby bezpieczeństwa",
            "england": "anglia",
            "and catalonia": "i katalonia",
            "the west indies": "indie zachodnie",
            "and unborn children": "i nienarodzone dzieci",
            "divorced people": "osoby rozwiedzione",
            "of new discoveries": "nowych odkryć",
            "fathers": "ojcowie",
            "grandparents": "dziadkowie",
            "the ordinary opus dei": "ordynariat opus dei",
            "the ordinary – opus dei": "ordynariat opus dei",
            "families": "rodziny",
            "carpenters": "cieśle",
            "unmarried women": "niezamężne kobiety",
            "hopeless cases": "beznadziejne sprawy",
            "desperate situations": "rozpaczliwe sytuacje",
            "rome": "rzym",
            "chefs": "kucharze",
            "eye illness": "choroby oczu",
            "money": "pieniądze",
            "bankers": "bankierzy",
            "tax collectors": "poborcy podatkowi",
            "wives": "żony",
            "and abuse victims": "i ofiary przemocy",
            "civil defense volunteers": "wolontariusze obrony cywilnej",
            "ireland": "irlandia",
            "engineers": "inżynierowie",
            "cancer patient": "pacjent onkologiczny",
            "net makers": "wytwórcy sieci",
            "and ship builders": "i budowniczowie statków",
            "joy": "radość",
            "usa forces": "siły zbrojne stanów zjednoczonych",
            "babies": "niemowlęta",
            "youth": "młodzież",
            "impossible causes": "sprawy niemożliwe",
            "wounds": "rany",
            "marital problems": "problemy małżeńskie",
            "nuns": "zakonnice",
            "against storms": "przeciw burzom",
            "against lightning": "przeciw piorunom",
            "against rain": "przeciw deszczowi",
            "soldiers": "żołnierze",
            "athletes": "sportowcy",
            "and those who desire a saintly": "i ci, którzy pragną świętego życia",
            "deacons": "diakoni",
            "altar servers": "ministranci",
            "casket makers": "wytwórcy trumien"
        ]

        let normalizedText = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        if locale == .es, let mapped = phraseMapES[normalizedText] { return mapped.capitalized(with: Locale(identifier: "es")) }
        if locale == .pl, let mapped = phraseMapPL[normalizedText] { return mapped.capitalized(with: Locale(identifier: "pl")) }
        return text
    }

    private func normalized(_ value: String) -> String {
        SearchMatcher.normalize(value)
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
    let document: SearchMatcher.Document
}

struct GlobalSearchView: View {
    @EnvironmentObject private var localization: LocalizationManager
    let environment: AppEnvironment

    var body: some View {
        TabView {
            SaintsSearchView(environment: environment)
                .tabItem { Label(localization.t("tab.saints"), systemImage: "person.2.fill") }
            NovenasSearchView(environment: environment)
                .tabItem { Label(localization.t("tab.novenas"), systemImage: "book.closed.fill") }
        }
        .tint(AppTheme.tabActive)
    }
}

private struct SearchHeader: View {
    let title: String
    let dismiss: () -> Void

    var body: some View {
        HStack {
            Button(action: dismiss) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(AppTheme.cardBackgroundSoft)
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .contentShape(Circle())

            Spacer()

            Text(title)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 52, height: 52)
        }
        .padding(.top, 8)
    }
}

private struct SearchField: View {
    let prompt: String
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.cardText.opacity(0.75))
            TextField(
                "",
                text: $text,
                prompt: Text(prompt)
                    .foregroundColor(AppTheme.cardText.opacity(0.58))
            )
                .foregroundColor(AppTheme.cardText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { onSubmit?() }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .appGlassCard(cornerRadius: 28)
    }
}

private struct SearchResultsCount: View {
    @EnvironmentObject private var localization: LocalizationManager
    let count: Int

    var body: some View {
        HStack {
            Text("\(count) \(localization.t("search.results"))")
                .font(AppTheme.rounded(17, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
            Spacer()
        }
    }
}

private struct SearchResultCard: View {
    let title: String
    let subtitle: String
    let meta: String?
    let accent: Color
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(AppTheme.rounded(20, weight: .bold))
                    .foregroundStyle(AppTheme.cardText)
                    .lineLimit(2)
                Text(subtitle)
                    .font(AppTheme.rounded(15, weight: .medium))
                    .foregroundStyle(AppTheme.cardText.opacity(0.78))
                    .lineLimit(3)
                if let meta, !meta.isEmpty {
                    Text(meta)
                        .font(AppTheme.rounded(12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.68))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.cardBackgroundSoft)
                        .clipShape(Capsule())
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.52))
                .padding(.top, 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .appGlassCard(cornerRadius: 24)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
