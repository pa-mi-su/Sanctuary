import SwiftUI

struct NovenasListView: View {
    @StateObject private var viewModel: NovenasListViewModel
    @EnvironmentObject private var localization: LocalizationManager

    init(viewModel: NovenasListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                ForEach(viewModel.novenas) { novena in
                    NavigationLink {
                        NovenaDetailView(novena: novena)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.title(for: novena))
                                .font(.headline)
                            Text(viewModel.summary(for: novena))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Text(viewModel.dayText(for: novena))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .navigationTitle(localization.t("tab.novenas"))
            .searchable(text: $viewModel.query, prompt: localization.t("search.novenasPrompt"))
            .onSubmit(of: .search) {
                Task { await viewModel.search() }
            }
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
        }
    }
}

struct NovenasListView_Previews: PreviewProvider {
    static var previews: some View {
        let environment = AppEnvironment.local()
        let viewModel = NovenasListViewModel(
            useCase: ListNovenasUseCase(contentRepository: environment.contentRepository)
        )
        NovenasListView(viewModel: viewModel)
    }
}
