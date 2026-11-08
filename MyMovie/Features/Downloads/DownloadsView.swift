import SwiftUI
struct DownloadsView: View {
    @Environment(AppStore.self) private var store
    @State private var removing: TorrentJob?
    var body: some View {
        List {
            if store.downloads.jobs.isEmpty {
                ContentUnavailableView("Your downloads", systemImage: "arrow.down.circle", description: Text("Choose a torrent stream, open a magnet link, or import a .torrent file. Videos download directly to this device."))
                Button("Add a download", systemImage: "plus") { store.showOpenStream = true }
            }
            ForEach(store.downloads.jobs) { job in
                NavigationLink { DownloadDetailView(hash: job.id) } label: {
                    DownloadRow(job: job, snapshot: store.downloads.snapshot(job.id))
                }
                .swipeActions(edge: .leading) { Button(job.paused ? "Resume" : "Pause", systemImage: job.paused ? "play" : "pause") { Task { await store.downloads.pause(job) } }.tint(Theme.accent) }
                .swipeActions { Button("Delete", role: .destructive) { removing = job } }
            }
            Section { Text("Downloads pause when iOS suspends the app and resume when you return. Keep the app open while downloading.").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("Downloads")
        .toolbar { Button("Add download", systemImage: "plus") { store.showOpenStream = true } }
        .confirmationDialog("Delete this download and its files?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button("Delete download", role: .destructive) { if let removing { Task { await store.downloads.remove(removing) } }; removing = nil }
        }
        .alert("Download problem", isPresented: Binding(get: { store.downloads.error != nil }, set: { if !$0 { store.downloads.error = nil } })) { } message: { Text(store.downloads.error ?? "") }
    }
}
struct DownloadRow: View {
    let job: TorrentJob
    let snapshot: TorrentSnapshot?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot?.metadata == true ? snapshot!.name : job.title).font(.headline).lineLimit(2)
            ProgressView(value: snapshot?.progress ?? 0)
            if let snapshot {
                HStack {
                    Text(job.paused ? "Paused" : snapshot.finished ? "Complete" : snapshot.metadata ? "\(Int(snapshot.progress * 100))%" : "Finding metadata…")
                    Spacer()
                    Text("\(ByteCountFormatter.string(fromByteCount: snapshot.downloadRate, countStyle: .file))/s · \(snapshot.peers) peers")
                }.font(.caption).foregroundStyle(.secondary)
                if !snapshot.error.isEmpty { Text(snapshot.error).font(.caption).foregroundStyle(.red) }
            } else { Text("Connecting…").font(.caption).foregroundStyle(.secondary) }
        }.padding(.vertical, 7)
    }
}
