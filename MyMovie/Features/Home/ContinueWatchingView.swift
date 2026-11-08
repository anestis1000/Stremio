import SwiftUI
struct ContinueWatchingView: View {
    @Environment(AppStore.self) private var store
    private var entries: [WatchProgress] { store.progress.filter { $0.fraction < 0.95 && $0.seconds > 5 } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Continue watching").font(.title3.bold()).padding(.horizontal, 20)
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(entries) { entry in
                        Button { store.play(entry) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ArtworkView(url: entry.item.background ?? entry.item.poster)
                                    .frame(width: 240, height: 135).clipped().clipShape(.rect(cornerRadius: 12))
                                    .overlay { Image(systemName: "play.circle.fill").font(.largeTitle).foregroundStyle(.white) }
                                ProgressView(value: entry.fraction).tint(Theme.accent)
                                Text(entry.title).font(.subheadline.weight(.medium)).lineLimit(1)
                            }.frame(width: 240)
                        }.buttonStyle(.plain)
                            .contextMenu { Button("Remove from history", role: .destructive) { store.removeProgress(entry) } }
                    }
                }.padding(.horizontal, 20)
            }.scrollIndicators(.hidden)
        }
    }
}
