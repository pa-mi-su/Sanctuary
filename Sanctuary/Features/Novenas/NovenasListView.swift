import SwiftUI

struct NovenasListView: View {
    @StateObject private var viewModel: NovenasListViewModel
    @EnvironmentObject private var localization: LocalizationManager

    init(viewModel: NovenasListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                List {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .listRowBackground(Color.clear)
                    }

                    ForEach(viewModel.novenas) { novena in
                        NavigationLink {
                            NovenaDetailView(novena: novena)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(viewModel.title(for: novena))
                                    .font(AppTheme.rounded(20, weight: .bold))
                                    .foregroundStyle(AppTheme.cardText)
                                Text(viewModel.summary(for: novena))
                                    .font(AppTheme.rounded(15, weight: .medium))
                                    .foregroundStyle(AppTheme.cardText.opacity(0.8))
                                    .lineLimit(2)
                                Text(viewModel.dayText(for: novena))
                                    .font(AppTheme.rounded(12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.68))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AppTheme.cardBackgroundSoft)
                                    .clipShape(Capsule())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 15)
                            .appGlassCard(cornerRadius: 24)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowSpacing(12)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)
            .overlay {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
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
