import SwiftUI
struct MediaGrid: View {
    let items: [MediaItem]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 200), spacing: 16)], spacing: 24) {
            ForEach(items, id: \.key) { item in
                NavigationLink(value: item) {
                    VStack(alignment: .leading, spacing: 8) {
                        Color.clear.aspectRatio(0.68, contentMode: .fit)
                            .overlay { ArtworkView(url: item.poster) }.clipped().clipShape(.rect(cornerRadius: 12))
                        Text(item.name).font(.subheadline.weight(.medium)).lineLimit(2)
                        Text(item.yearLabel).font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
            }
        }
    }
}
