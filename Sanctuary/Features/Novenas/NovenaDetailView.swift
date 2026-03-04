import SwiftUI

struct NovenaDetailView: View {
    let novena: Novena
    private let locale: ContentLocale = .en

    var body: some View {
        List {
            Section("About") {
                Text(novena.titleByLocale[locale] ?? novena.slug)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(novena.descriptionByLocale[locale] ?? "")
                    .foregroundStyle(.secondary)
            }

            Section("Days") {
                ForEach(novena.days, id: \.dayNumber) { day in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Day \(day.dayNumber)")
                            .font(.headline)
                        Text(day.bodyByLocale[locale] ?? "")
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(novena.titleByLocale[locale] ?? "Novena")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

struct NovenaDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NovenaDetailView(novena: LocalSeedData.novenas[0])
    }
}
