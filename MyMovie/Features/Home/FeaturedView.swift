import SwiftUI
struct FeaturedView: View {
    let item: MediaItem
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(url: item.background ?? item.poster).frame(height: 390).clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.4), .black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 14) {
                Text(item.name).font(.largeTitle.bold()).foregroundStyle(.white)
                HStack(spacing: 12) {
                    Text(item.yearLabel)
                    if let rating = item.imdbRating, !rating.isEmpty { Label(rating, systemImage: "star.fill") }
                    if let genre = item.genres?.first { Text(genre) }
                }.font(.subheadline).foregroundStyle(.white.opacity(0.85))
                NavigationLink(value: item) { Label("Explore title", systemImage: "play.fill").frame(minHeight: 32) }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
            }.padding(24)
        }.frame(height: 390).clipShape(.rect(cornerRadius: 20)).padding(.horizontal, 20)
    }
}
