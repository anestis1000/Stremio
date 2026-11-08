import SwiftUI
struct OpenStreamView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var error: String?
    @State private var playback: PlaybackRequest?
    var body: some View {
        NavigationStack {
            Form {
                Section("Video address") {
                    TextField("https://example.com/video.m3u8", text: $address).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Open an HTTP video or HLS stream you have permission to watch. iOS-supported formats play with native controls, AirPlay, and embedded audio/subtitle tracks.").font(.footnote).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                Button("Play stream", systemImage: "play.fill") {
                    guard let url = URL(string: address.trimmingCharacters(in: .whitespacesAndNewlines)), ["http", "https"].contains(url.scheme ?? ""), url.host != nil else {
                        error = "Enter a complete HTTP or HTTPS video URL."; return
                    }
                    error = nil; playback = PlaybackRequest(url: url, item: nil, videoID: url.absoluteString, title: url.lastPathComponent)
                }.disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("Open stream").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .fullScreenCover(item: $playback) { PlayerView(request: $0) }
        }
    }
}
