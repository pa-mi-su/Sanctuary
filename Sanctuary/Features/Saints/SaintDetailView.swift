import SwiftUI

struct SaintDetailView: View {
    let saint: Saint
    private let locale: ContentLocale = .en

    var body: some View {
        List {
            Section("Profile") {
                Text(saint.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Feast day: \(saint.feastMonth)/\(saint.feastDay)")
                    .foregroundStyle(.secondary)
                if !saint.patronages.isEmpty {
                    Text("Patronages: \(saint.patronages.joined(separator: ", "))")
                        .font(.subheadline)
                }
            }

            Section("Biography") {
                Text(saint.biographyByLocale[locale] ?? saint.biographyByLocale[.en] ?? "")
            }
        }
        .navigationTitle(saint.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

struct SaintDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SaintDetailView(saint: previewSaint)
    }

    private static var previewSaint: Saint {
        LocalSeedData.saints[0]
    }
}
