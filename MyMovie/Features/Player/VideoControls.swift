import SwiftUI
struct VideoControls: View {
    let model: PlaybackModel
    var body: some View {
        Section("Video") {
            if model.qualities.count > 1 {
                Picker("Quality / source", selection: Binding(get: { model.selectedQuality }, set: { id in
                    if let quality = model.qualities.first(where: { $0.id == id }) { model.selectQuality(quality) }
                })) { ForEach(model.qualities) { Text($0.title).tag($0.id) } }
            } else { Text("The selected source controls video quality.").font(.caption).foregroundStyle(.secondary) }
            Picker("Playback speed", selection: Binding(get: { model.rate }, set: model.setRate)) {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { Text("\($0.formatted())×").tag($0) }
            }
            if !model.videoDescription.isEmpty { Text(model.videoDescription).font(.caption).textSelection(.enabled) }
            Text("mpv · Native FFmpeg · VideoToolbox hardware decoding").font(.caption).foregroundStyle(.secondary)
        }
    }
}
