import SwiftUI
struct CatalogShelf: View {
    let title: String
    let items: [MediaItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title3.bold()).padding(.horizontal, 20)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(items, id: \.key) { item in
                        NavigationLink(value: item) { PosterCard(item: item) }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 20)
            }.scrollIndicators(.hidden)
        }
    }
}
