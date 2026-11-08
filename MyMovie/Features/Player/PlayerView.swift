import SwiftUI
struct PlayerView: View {
    let request: PlaybackRequest
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = PlaybackModel()
    @State private var controlsVisible = true
    @State private var options = false
    @State private var fill = false
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MPVVideoSurface(model: model).ignoresSafeArea()
                .contentShape(.rect).onTapGesture { controlsVisible.toggle() }
            if model.loading || model.buffering {
                ProgressView(model.loading ? "Opening stream…" : "Buffering…")
                    .padding(20).background(.black.opacity(0.7), in: .rect(cornerRadius: 12)).foregroundStyle(.white).tint(.white)
            }
            if controlsVisible || model.error != nil {
                VStack {
                    HStack(spacing: 16) {
                        Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
                        Text(request.title).font(.headline).lineLimit(2)
                        Spacer()
                        Button("Playback settings", systemImage: "slider.horizontal.3") { options = true }.labelStyle(.iconOnly)
                    }.padding(16).background(.black.opacity(0.7))
                    Spacer()
                    if let error = model.error {
                        ContentUnavailableView("Unable to play this stream", systemImage: "exclamationmark.triangle", description: Text(error)).foregroundStyle(.white)
                    }
                    Spacer()
                    PlaybackControls(model: model, fill: $fill)
                }
            }
        }
        .foregroundStyle(.white).buttonStyle(.bordered).tint(.white)
        .preferredColorScheme(.dark).statusBarHidden(!controlsVisible)
        .sheet(isPresented: $options) { PlayerOptionsView(model: model) }
        .task { model.start(request, store: store); await model.discoverOptions() }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.background() }
            else if phase == .active { model.foreground() }
        }
        .alert("Playback", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) { } message: { Text(model.notice ?? "") }
    }
}
