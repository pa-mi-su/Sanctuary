import SwiftUI

struct SaintsListView: View {
    @StateObject private var viewModel: SaintsListViewModel
    @EnvironmentObject private var localization: LocalizationManager

    init(viewModel: SaintsListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                ForEach(viewModel.saints) { saint in
                    NavigationLink {
                        SaintDetailView(saint: saint)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.displayName(for: saint))
                                .font(.headline)
                            Text(viewModel.summary(for: saint))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Text("\(localization.t("saints.feastShort")): \(saint.feastMonth)/\(saint.feastDay)")
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
            .navigationTitle(localization.t("tab.saints"))
            .searchable(text: $viewModel.query, prompt: localization.t("search.saintsPrompt"))
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

struct SaintsListView_Previews: PreviewProvider {
    static var previews: some View {
        let environment = AppEnvironment.local()
        let viewModel = SaintsListViewModel(
            useCase: ListSaintsUseCase(contentRepository: environment.contentRepository)
        )
        SaintsListView(viewModel: viewModel)
    }
}
