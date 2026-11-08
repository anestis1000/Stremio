import SwiftUI
struct StreamsView: View {
    let request: StreamRequest
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var choices: [StreamChoice] = []
    @State private var loading = true
    @State private var failures: [String] = []
    @State private var message: String?
    @State private var player: PlaybackRequest?
    @State private var preparing = false
    @State private var showAddons = false
    var body: some View {
        NavigationStack {
            List {
                Section { Text(request.title).font(.title3.bold()) }
                if loading { ProgressView("Checking your addons…") }
                if preparing { ProgressView("Preparing stream and torrent metadata…") }
                ForEach(choices) { choice in
                    Button { Task { await select(choice.stream) } } label: {
                        HStack(spacing: 14) {
                            Image(systemName: choice.stream.externalUrl == nil ? "play.circle.fill" : "arrow.up.forward.app")
                                .font(.title2).foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(choice.stream.label).font(.headline)
                                Text(choice.stream.detail).font(.subheadline).foregroundStyle(.secondary)
                                Text(choice.addonName).font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 6)
                    }.buttonStyle(.plain).disabled(preparing)
                }
                if !loading && choices.isEmpty {
                    ContentUnavailableView("No streams found", systemImage: "play.slash", description: Text("Install a stream addon, then try again. Cinemeta provides title information."))
                }
                if !loading { Button("Manage stream addons", systemImage: "puzzlepiece.extension") { showAddons = true } }
                if !failures.isEmpty {
                    Section("Addon responses") { ForEach(failures, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) } }
                }
            }
            .navigationTitle("Streams").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .refreshable { await load() }
            .task { await load() }
            .sheet(isPresented: $showAddons, onDismiss: { Task { await load() } }) { NavigationStack { AddonsView().toolbar { Button("Done") { showAddons = false } } } }
            .fullScreenCover(item: $player) { PlayerView(request: $0) }
            .alert("Playback unavailable", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { } message: { Text(message ?? "") }
        }
    }
    private func load() async {
        loading = true; choices = []; failures = []
        for addon in store.addons where addon.manifest.supports("stream", type: request.item.type, id: request.videoID) {
            do {
                let streams = try await store.client.streams(type: request.item.type, videoID: request.videoID, addon: addon)
                try Task.checkCancellation()
                choices += streams.enumerated().map { index, stream in StreamChoice(id: addon.id + ":\(index)", addonName: addon.manifest.name, stream: stream) }
            } catch is CancellationError { return }
            catch { failures.append(addon.manifest.name + ": " + error.localizedDescription) }
        }
        loading = false
    }
    private func select(_ stream: MediaStream) async {
        if let external = stream.externalUrl { openURL(external); return }
        if let youtube = stream.ytId, let url = URL(string: "https://www.youtube.com/watch?v=" + youtube) { openURL(url); return }
        preparing = true; defer { preparing = false }
        do {
            let url: URL
            var torrentHash: String?
            if stream.infoHash != nil {
                let hash = try await store.downloads.add(stream: stream, title: request.title)
                torrentHash = hash
                url = try await store.downloads.playbackURL(hash: hash, index: stream.fileIdx)
            } else if let direct = stream.url, ["http", "https"].contains(direct.scheme ?? "") { url = direct }
            else { throw TorrentError.message("This addon did not provide a playable video URL or torrent.") }
            let saved = store.progress.first { $0.item.key == request.item.key && $0.videoID == request.videoID }
            let hints = stream.behaviorHints
            let alternatives = choices.compactMap { choice -> PlaybackQuality? in
                guard let url = choice.stream.url, ["http", "https"].contains(url.scheme ?? "") else { return nil }
                return PlaybackQuality(title: choice.stream.label, url: url, headers: choice.stream.behaviorHints?.proxyHeaders?.request ?? [:])
            }
            player = PlaybackRequest(url: url, item: request.item, videoID: request.videoID, title: request.title, startTime: saved?.seconds ?? 0, subtitles: stream.subtitles ?? [], headers: hints?.proxyHeaders?.request ?? [:], subtitleHints: SubtitleHints(filename: hints?.filename, videoHash: hints?.videoHash, videoSize: hints?.videoSize), torrentHash: torrentHash, torrentFileIndex: stream.fileIdx, alternatives: alternatives)
        } catch { message = error.localizedDescription }
    }
}
