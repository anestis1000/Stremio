import SwiftUI
struct AudioControls: View {
    let model: PlaybackModel
    var body: some View {
        Section("Audio") {
            Picker("Audio track", selection: Binding(get: { model.selectedAudio }, set: { model.selectAudio($0) })) {
                Text("Off").tag(Int64(0))
                ForEach(model.audioTracks) { Text($0.label).tag($0.id) }
            }
            if model.audioTracks.isEmpty { Text("No audio tracks detected yet.").font(.caption).foregroundStyle(.secondary) }
            Slider(value: Binding(get: { model.volume }, set: { model.setVolume($0) }), in: 0...100) { Text("Volume") }
            LabeledContent("Volume", value: "\(Int(model.volume))%")
            Stepper(value: Binding(get: { model.audioDelay }, set: { model.setAudioDelay($0) }), in: -10...10, step: 0.1) {
                LabeledContent("Audio delay", value: "\(model.audioDelay.formatted(.number.precision(.fractionLength(1))))s")
            }
        }
    }
}
