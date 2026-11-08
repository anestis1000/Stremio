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
    var body: some View {
        NavigationStack {
            List {
                Section { Text(request.title).font(.title3.bold()) }
                if loading { ProgressView("Checking your addons…") }
                ForEach(choices) { choice in
                    Button { select(choice.stream) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: choice.stream.externalUrl == nil ? "play.circle.fill" : "arrow.up.forward.app")
                                .font(.title2).foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(choice.stream.label).font(.headline)
                                Text(choice.stream.detail).font(.subheadline).foregroundStyle(.secondary)
                                Text(choice.addonName).font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 6)
                    }.buttonStyle(.plain)
                }
                if !loading && choices.isEmpty {
                    ContentUnavailableView("No streams found", systemImage: "play.slash", description: Text("Install a stream addon in Addons, then try again. Cinemeta provides title information, not video streams."))
                }
                if !failures.isEmpty {
                    Section("Addon responses") { ForEach(failures, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) } }
                }
            }
            .navigationTitle("Streams").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .refreshable { await load() }
            .task { await load() }
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
    private func select(_ stream: MediaStream) {
        if let external = stream.externalUrl { openURL(external); return }
        if let youtube = stream.ytId, let url = URL(string: "https://www.youtube.com/watch?v=" + youtube) { openURL(url); return }
        var playable = stream.url
        if playable == nil, let hash = stream.infoHash {
            guard let server = URL(string: store.streamingServer), ["http", "https"].contains(server.scheme ?? ""), server.host != nil else {
                message = "This source needs a Stremio streaming service. Add your service address in Settings, or select a direct HTTP/HLS stream."; return
            }
            guard let index = stream.fileIdx else { message = "This source does not specify a file index. Choose a direct stream or a source with an explicit file."; return }
            playable = server.appendingPathComponent(hash).appendingPathComponent(String(index))
        }
        guard let url = playable, ["http", "https"].contains(url.scheme ?? "") else {
            message = "This source cannot be played by the iOS player. Choose an HTTP or HLS stream."; return
        }
        let saved = store.progress.first { $0.item.key == request.item.key && $0.videoID == request.videoID }
        player = PlaybackRequest(url: url, item: request.item, videoID: request.videoID, title: request.title, startTime: saved?.seconds ?? 0)
    }
}
