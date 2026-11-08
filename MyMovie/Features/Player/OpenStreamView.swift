import SwiftUI
import UniformTypeIdentifiers
struct OpenStreamView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var address = ""
    @State private var error: String?
    @State private var playback: PlaybackRequest?
    @State private var importing = false
    @State private var busy = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Video or magnet link") {
                    TextField("https://… or magnet:?xt=…", text: $address).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Open a video URL or download a torrent directly to this device. Torrent progress and files appear in Downloads.").font(.footnote).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                if busy { ProgressView("Opening…") }
                Button("Open link", systemImage: "play.fill") { Task { await openLink() } }.disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                Button("Import video or .torrent file", systemImage: "folder") { importing = true }.disabled(busy)
            }
            .navigationTitle("Open stream").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .fullScreenCover(item: $playback) { PlayerView(request: $0) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.movie, UTType(filenameExtension: "torrent") ?? .data]) { result in
                switch result { case .success(let url): Task { await importFile(url) }; case .failure(let failure): error = failure.localizedDescription }
            }
        }
    }
    private func openLink() async {
        busy = true; error = nil; defer { busy = false }
        do {
            guard let url = URL(string: address.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw TorrentError.message("Enter a complete video URL or magnet link.") }
            if url.scheme == "magnet" { _ = try await store.downloads.add(magnet: url.absoluteString); dismiss() }
            else if ["http", "https"].contains(url.scheme ?? ""), url.host != nil {
                if url.pathExtension.lowercased() == "torrent" {
                    let (local, response) = try await URLSession.shared.download(from: url)
                    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw TorrentError.message("Could not download the torrent file.") }
                    _ = try await store.downloads.add(torrent: local); dismiss()
                } else { playback = PlaybackRequest(url: url, item: nil, videoID: url.absoluteString, title: url.lastPathComponent) }
            } else { throw TorrentError.message("Use an HTTP video URL, a torrent URL, or a magnet link.") }
        } catch { self.error = error.localizedDescription }
    }
    private func importFile(_ url: URL) async {
        busy = true; defer { busy = false }
        do {
            if url.pathExtension.lowercased() == "torrent" { _ = try await store.downloads.add(torrent: url); dismiss(); return }
            let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
            let directory = URL.documentsDirectory.appendingPathComponent("Imported Videos", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let local = directory.appendingPathComponent(UUID().uuidString + "." + url.pathExtension)
            try FileManager.default.copyItem(at: url, to: local)
            playback = PlaybackRequest(url: local, item: nil, videoID: local.absoluteString, title: url.lastPathComponent)
        } catch { self.error = error.localizedDescription }
    }
}
