import SwiftUI

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
                VStack(alignment: .leading, spacing: 4) {
                    Text(saint.name).font(.headline)
                    Text(viewModel.biography(for: saint))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .searchable(text: $viewModel.query, prompt: "Search saints")
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
            .navigationTitle("Search Saints")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct NovenasSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager
    @StateObject private var viewModel: NovenasListViewModel

    init(environment: AppEnvironment) {
        _viewModel = StateObject(
            wrappedValue: NovenasListViewModel(
                useCase: ListNovenasUseCase(contentRepository: environment.contentRepository)
            )
        )
    }

    var body: some View {
        NavigationStack {
            List(viewModel.novenas) { novena in
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.title(for: novena)).font(.headline)
                    Text(viewModel.summary(for: novena))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .searchable(text: $viewModel.query, prompt: "Search novenas")
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
            .navigationTitle("Search Novenas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
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
