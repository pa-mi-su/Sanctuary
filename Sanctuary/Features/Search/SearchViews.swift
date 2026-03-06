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
                        Text(saint.name).font(.headline)
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
            let rawIntentions = localizedIntentions(doc: doc, locale: locale)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !rawIntentions.isEmpty else { return nil }
            let intentions = rawIntentions.map(humanizeIntention)

            let title = viewModel.title(for: novena)
            let searchBlob = normalized(
                "\(title) \(novena.slug) \((novena.tags).joined(separator: " ")) \(rawIntentions.joined(separator: " ")) \(intentions.joined(separator: " "))"
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
            return doc.intentions_es ?? doc.intentions ?? doc.intentions_pl ?? []
        case .pl:
            return doc.intentions_pl ?? doc.intentions ?? doc.intentions_es ?? []
        }
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
    let environment: AppEnvironment

    var body: some View {
        TabView {
            SaintsSearchView(environment: environment)
                .tabItem { Label("Saints", systemImage: "person.2") }
            NovenasSearchView(environment: environment)
                .tabItem { Label("Novenas", systemImage: "book") }
        }
    }
}
