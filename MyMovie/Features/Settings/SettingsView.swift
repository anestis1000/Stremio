import SwiftUI
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmClear = false
    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Label { VStack(alignment: .leading, spacing: 5) {
                    Text("Your space, on this device").font(.headline)
                    Text("Guest library and watch progress").font(.subheadline).foregroundStyle(.secondary)
                } } icon: { Image(systemName: "person.crop.circle").font(.largeTitle).foregroundStyle(Theme.accent) }
                    .padding(.vertical, 8)
            }
            Section("Appearance") {
                Picker("Theme", selection: $store.appearance) { ForEach(Appearance.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            }
            Section("Playback") {
                Button("Open video or torrent", systemImage: "play.rectangle") { store.showOpenStream = true }
                Text("mpv uses native FFmpeg libraries with VideoToolbox hardware decoding. Choose audio tracks, embedded or external subtitles, timing, speed, volume, and video fit in the player's settings.").font(.footnote).foregroundStyle(.secondary)
                LabeledContent("FFmpeg", value: NativeFFmpeg.version)
                Text("Torrents download on this device. iOS suspends torrent transfers in the background; return to the app to resume.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Watch history") {
                LabeledContent("Saved progress", value: store.progress.count.formatted())
                ForEach(store.progress.prefix(10)) { entry in
                    Button { store.play(entry) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.title).foregroundStyle(.primary)
                            Text(entry.updatedAt, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                        }
                    }.swipeActions { Button("Remove", role: .destructive) { store.removeProgress(entry) } }
                }
                Button("Clear watch history", role: .destructive) { confirmClear = true }
                    .disabled(store.progress.isEmpty)
                    .confirmationDialog("Clear watch history on this device?", isPresented: $confirmClear, titleVisibility: .visible) {
                        Button("Clear history", role: .destructive) { store.resetHistory() }
                    }
            }
            Section("About") {
                LabeledContent("Version", value: "1.0")
                Text("An independent native SwiftUI client based on the Stremio addon protocol. This build stores data locally; account login and cross-device sync are not included.").font(.footnote).foregroundStyle(.secondary)
                Link("Stremio addon protocol", destination: URL(string: "https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/protocol.md")!)
            }
        }.navigationTitle("Settings")
    }
}
