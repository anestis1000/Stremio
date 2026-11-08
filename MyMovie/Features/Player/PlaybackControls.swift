import SwiftUI
struct PlaybackControls: View {
    let model: PlaybackModel
    @Binding var fill: Bool
    @State private var seekPosition = 0.0
    @State private var scrubbing = false
    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 30) {
                Button("Back 10 seconds", systemImage: "gobackward.10") { model.skip(-10) }
                Button(model.ended ? "Replay" : model.paused ? "Play" : "Pause", systemImage: model.ended ? "arrow.counterclockwise" : model.paused ? "play.fill" : "pause.fill") { model.togglePause() }
                    .font(.title).frame(width: 64, height: 52)
                Button("Forward 10 seconds", systemImage: "goforward.10") { model.skip(10) }
            }.labelStyle(.iconOnly).font(.title2)
            Slider(value: Binding(get: { scrubbing ? seekPosition : min(model.position, max(model.duration, 1)) }, set: { seekPosition = $0 }), in: 0...max(model.duration, 1)) { editing in
                scrubbing = editing
                if !editing { model.seek(seekPosition) }
            }.disabled(model.duration <= 0).accessibilityLabel("Playback position")
            HStack {
                Text(Self.time(scrubbing ? seekPosition : model.position))
                Spacer()
                if model.cacheSeconds > 0 { Text("\(Int(model.cacheSeconds))s buffered").foregroundStyle(.white.opacity(0.7)) }
                Spacer()
                Text(Self.time(model.duration))
            }.font(.caption.monospacedDigit())
            HStack {
                Menu {
                    Button("Mute") { model.setVolume(0) }
                    Button("50%") { model.setVolume(50) }
                    Button("100%") { model.setVolume(100) }
                } label: { Label("Volume", systemImage: model.volume == 0 ? "speaker.slash" : "speaker.wave.2") }
                Spacer()
                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { rate in Button("\(rate.formatted())×") { model.setRate(rate) } }
                } label: { Text("\(model.rate.formatted())×") }
                Spacer()
                Button(fill ? "Fit video" : "Fill screen", systemImage: fill ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                    fill.toggle(); model.setFill(fill)
                }.labelStyle(.iconOnly)
            }.font(.subheadline)
        }.padding(20).background(.black.opacity(0.78))
    }
    static func time(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "0:00" }
        let total = Int(value)
        return total >= 3600 ? String(format: "%d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60) : String(format: "%d:%02d", total / 60, total % 60)
    }
}
