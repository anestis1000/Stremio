import SwiftUI
struct DetailView: View {
    let item: MediaItem
    @Environment(AppStore.self) private var store
    @State private var metadata: MediaItem?
    @State private var loading = false
    @State private var error: String?
    @State private var selectedSeason = 1
    @State private var streamRequest: StreamRequest?
    @State private var seasons: [Int] = []
    @State private var episodes: [MediaVideo] = []
    private var media: MediaItem { metadata ?? item }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DetailHeader(item: media, saved: store.contains(media)) { store.toggleLibrary(media) }
                if loading { ProgressView("Loading details…").frame(maxWidth: .infinity) }
                if let error {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error).font(.callout).foregroundStyle(.secondary)
                        Button("Retry details") { Task { await load() } }
                    }.padding(.horizontal, 20)
                }
                if media.type == "series" {
                    EpisodeList(seasons: seasons, selection: $selectedSeason, episodes: episodes) { video in
                        streamRequest = StreamRequest(item: media, videoID: video.id, title: video.displayName)
                    }
                } else {
                    Button { streamRequest = StreamRequest(item: media, videoID: media.id, title: media.name) } label: {
                        Label("Find streams", systemImage: "play.fill").frame(maxWidth: .infinity, minHeight: 36)
                    }.buttonStyle(.borderedProminent).padding(.horizontal, 20)
                }
                if let description = media.description { Text(description).font(.body).textSelection(.enabled).padding(.horizontal, 20) }
                if let cast = media.cast, !cast.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Cast").font(.title3.bold())
                        Text(cast.formatted(.list(type: .and))).foregroundStyle(.secondary)
                    }.padding(.horizontal, 20)
                }
            }.padding(.bottom, 30)
        }
        .background(Theme.background).navigationTitle(media.name).navigationBarTitleDisplayMode(.inline)
        .sheet(item: $streamRequest) { StreamsView(request: $0) }
        .task { await load() }
        .onChange(of: selectedSeason) { updateEpisodes() }
    }

    private func load() async {
        loading = true; error = nil
        let candidates = store.addons.filter { $0.manifest.supports("meta", type: item.type, id: item.id) }
        for addon in candidates {
            do {
                let meta = try await store.client.metadata(item, from: addon)
                try Task.checkCancellation()
                metadata = meta
                seasons = Array(Set((meta.videos ?? []).compactMap(\.season))).sorted()
                selectedSeason = seasons.first(where: { $0 > 0 }) ?? seasons.first ?? 1
                updateEpisodes(); loading = false; error = nil; return
            } catch is CancellationError { return }
            catch { self.error = error.localizedDescription }
        }
        if candidates.isEmpty { error = "No installed addon provides details for this title." }
        loading = false
    }

    private func updateEpisodes() {
        episodes = (media.videos ?? []).filter { $0.season == selectedSeason }.sorted { $0.episodeNumber < $1.episodeNumber }
    }
}
