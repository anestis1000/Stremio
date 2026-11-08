import SwiftUI
struct EpisodeList: View {
    let seasons: [Int]
    @Binding var selection: Int
    let episodes: [MediaVideo]
    let select: (MediaVideo) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Episodes").font(.title3.bold())
                Spacer()
                Picker("Season", selection: $selection) {
                    ForEach(seasons, id: \.self) { season in Text(season == 0 ? "Specials" : "Season \(season)").tag(season) }
                }.pickerStyle(.menu)
            }
            if episodes.isEmpty { Text("No episodes available from the installed metadata addons.").font(.callout).foregroundStyle(.secondary) }
            ForEach(episodes) { video in
                Button { select(video) } label: {
                    HStack(spacing: 14) {
                        ArtworkView(url: video.thumbnail).frame(width: 112, height: 68).clipped().clipShape(.rect(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(video.episodeNumber). \(video.displayName)").font(.subheadline.weight(.semibold)).lineLimit(2)
                            if let overview = video.overview ?? video.description { Text(overview).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "play.circle").foregroundStyle(Theme.accent).font(.title2)
                    }.padding(.vertical, 6).contentShape(.rect)
                }.buttonStyle(.plain)
            }
        }.padding(.horizontal, 20)
    }
}
