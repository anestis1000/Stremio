import SwiftUI
struct DownloadDetailView: View {
    let hash: String
    @Environment(AppStore.self) private var store
    @State private var playback: PlaybackRequest?
    @State private var message: String?
    @State private var probe: MediaProbe?
    @State private var preparing = false
    var body: some View {
        List {
            if let job = store.downloads.jobs.first(where: { $0.id == hash }) {
                Section { DownloadRow(job: job, snapshot: store.downloads.snapshot(hash))
                    Button(job.paused ? "Resume download" : "Pause download", systemImage: job.paused ? "play" : "pause") { Task { await store.downloads.pause(job) } }
                }
            }
            if preparing { ProgressView("Preparing video…") }
            Section("Files") {
                ForEach(store.downloads.snapshot(hash)?.files ?? []) { file in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(URL(fileURLWithPath: file.path).lastPathComponent).font(.headline)
                        Text("\(ByteCountFormatter.string(fromByteCount: file.downloaded, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file))").font(.caption).foregroundStyle(.secondary)
                        if file.isVideo {
                            Button("Watch", systemImage: "play.fill") { Task { await play(file) } }.disabled(preparing)
                            if file.downloaded >= file.bytes {
                                Button("Media information", systemImage: "info.circle") { Task { await inspect(file) } }
                                if let url = try? store.downloads.localFile(hash: hash, file: file) { ShareLink("Export file", item: url) }
                            }
                        }
                    }.padding(.vertical, 5)
                }
            }
            if let probe { Section(probe.format) { LabeledContent("Duration", value: "\(Int(probe.duration)) seconds"); ForEach(probe.streams, id: \.self) { Text($0) } } }
            Section { Text("Watching prioritizes the selected video. Other files stay on this device. Seeking may buffer while the requested pieces download.").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("Download").navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $playback) { PlayerView(request: $0) }
        .alert("Download", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { } message: { Text(message ?? "") }
    }
    private func play(_ file: TorrentFile) async {
        preparing = true; defer { preparing = false }
        do {
            let url = try await store.downloads.playbackURL(hash: hash, index: file.index)
            playback = PlaybackRequest(url: url, item: nil, videoID: hash + ":\(file.index)", title: URL(fileURLWithPath: file.path).lastPathComponent)
        } catch { message = error.localizedDescription }
    }
    private func inspect(_ file: TorrentFile) async {
        do { probe = try await NativeFFmpeg.shared.probe(file: store.downloads.localFile(hash: hash, file: file)) }
        catch { message = error.localizedDescription }
    }
}
