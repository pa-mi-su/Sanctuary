import SwiftUI

struct SaintsListView: View {
    @StateObject private var viewModel: SaintsListViewModel
    @EnvironmentObject private var localization: LocalizationManager

    init(viewModel: SaintsListViewModel) {
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

                    ForEach(viewModel.saints) { saint in
                        NavigationLink {
                            SaintDetailView(saint: saint)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(viewModel.displayName(for: saint))
                                    .font(AppTheme.rounded(20, weight: .bold))
                                    .foregroundStyle(AppTheme.cardText)
                                Text(viewModel.summary(for: saint))
                                    .font(AppTheme.rounded(15, weight: .medium))
                                    .foregroundStyle(AppTheme.cardText.opacity(0.8))
                                    .lineLimit(2)
                                Text("\(localization.t("saints.feastShort")): \(saint.feastMonth)/\(saint.feastDay)")
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
