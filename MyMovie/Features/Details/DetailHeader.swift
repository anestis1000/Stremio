import SwiftUI
struct DetailHeader: View {
    let item: MediaItem
    let saved: Bool
    let toggle: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ArtworkView(url: item.background ?? item.poster).frame(height: 245).clipped()
            VStack(alignment: .leading, spacing: 14) {
                Text(item.name).font(.largeTitle.bold())
                HStack(spacing: 12) {
                    Text(item.yearLabel)
                    if let runtime = item.runtime { Text(runtime) }
                    if let rating = item.imdbRating, !rating.isEmpty { Label(rating, systemImage: "star.fill").foregroundStyle(.yellow) }
                }.font(.subheadline).foregroundStyle(.secondary)
                if let genres = item.genres { Text(genres.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary) }
                Button(action: toggle) { Label(saved ? "In your library" : "Add to library", systemImage: saved ? "checkmark" : "plus").frame(minHeight: 32) }
                    .buttonStyle(.bordered)
            }.padding(.horizontal, 20)
        }
    }
}
