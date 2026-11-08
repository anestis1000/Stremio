import SwiftUI
import AVKit
struct PlayerView: View {
    let request: PlaybackRequest
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = PlaybackModel()
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VideoPlayer(player: model.player)
                if model.loading { ProgressView("Opening stream…").tint(.white).foregroundStyle(.white) }
                if let error = model.error {
                    ContentUnavailableView("Unable to play this stream", systemImage: "exclamationmark.triangle", description: Text(error))
                        .background(.black.opacity(0.85)).foregroundStyle(.white)
                }
            }
            .navigationTitle(request.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear { model.start(request, store: store) }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.save() } }
    }
}
