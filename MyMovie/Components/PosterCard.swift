import SwiftUI
struct PosterCard: View {
    let item: MediaItem
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ArtworkView(url: item.poster).frame(width: 128, height: 190).clipped().clipShape(.rect(cornerRadius: 12))
            Text(item.name).font(.subheadline.weight(.medium)).lineLimit(2)
            Text(item.yearLabel).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }.frame(width: 128, alignment: .topLeading).accessibilityElement(children: .combine)
    }
}
