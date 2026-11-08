import SwiftUI
import UniformTypeIdentifiers
struct PlayerOptionsView: View {
    let model: PlaybackModel
    @Environment(\.dismiss) private var dismiss
    @State private var importSubtitle = false
    @State private var subtitleURL = ""
    @State private var showURL = false
    var body: some View {
        NavigationStack {
            Form {
                AudioControls(model: model)
                SubtitleControls(model: model)
                Section("Add subtitles") {
                    Button("Import subtitle file", systemImage: "doc") { importSubtitle = true }
                    Button("Load subtitle URL", systemImage: "link") { showURL = true }
                    if model.loadingSubtitles { ProgressView("Loading subtitle…") }
                    ForEach(model.availableSubtitles, id: \.url) { subtitle in
                        Button { model.loadSubtitle(subtitle) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(subtitle.label ?? Locale.current.localizedString(forLanguageCode: subtitle.lang) ?? subtitle.lang)
                                Text(subtitle.url.host ?? "Imported file").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    ForEach(model.subtitleFailures, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                }
                VideoControls(model: model)
            }
            .navigationTitle("Playback settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: $importSubtitle, allowedContentTypes: [.item]) { result in
                do { model.importSubtitle(try result.get()) } catch { model.notice = error.localizedDescription }
            }
            .alert("Subtitle URL", isPresented: $showURL) {
                TextField("https://example.com/subtitle.srt", text: $subtitleURL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Cancel", role: .cancel) { }
                Button("Load") {
                    if let url = URL(string: subtitleURL), ["http", "https"].contains(url.scheme ?? ""), url.host != nil {
                        model.loadSubtitle(MediaSubtitle(id: url.absoluteString, url: url, lang: "und", label: url.lastPathComponent))
                    } else { model.notice = "Enter a complete HTTP or HTTPS subtitle URL." }
                }
            }
        }.preferredColorScheme(.dark)
    }
}
