import SwiftUI
struct SubtitleControls: View {
    let model: PlaybackModel
    var body: some View {
        Section("Subtitles") {
            Picker("Subtitle track", selection: Binding(get: { model.selectedSubtitle }, set: { model.selectSubtitle($0) })) {
                Text("Off").tag(Int64(0))
                ForEach(model.subtitleTracks) { Text($0.label).tag($0.id) }
            }
            Stepper(value: Binding(get: { model.subtitleDelay }, set: { model.setSubtitleDelay($0) }), in: -60...60, step: 0.1) {
                LabeledContent("Subtitle delay", value: "\(model.subtitleDelay.formatted(.number.precision(.fractionLength(1))))s")
            }
            Slider(value: Binding(get: { model.subtitleScale }, set: { model.setSubtitleScale($0) }), in: 0.5...2.5) { Text("Subtitle size") }
            LabeledContent("Subtitle size", value: "\(Int(model.subtitleScale * 100))%")
            Slider(value: Binding(get: { model.subtitlePosition }, set: { model.setSubtitlePosition($0) }), in: 0...100) { Text("Vertical position") }
            LabeledContent("Vertical position", value: "\(Int(model.subtitlePosition))%")
            Toggle("Use embedded ASS styling", isOn: Binding(get: { model.useASSStyling }, set: { model.setASSStyling($0) }))
        }
    }
}
