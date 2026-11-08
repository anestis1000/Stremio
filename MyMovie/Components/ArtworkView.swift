import SwiftUI
struct ArtworkView: View {
    let url: URL?
    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image { image.resizable().scaledToFill() }
            else { Rectangle().fill(Theme.surface).overlay { Image(systemName: "film").font(.largeTitle).foregroundStyle(.secondary) } }
        }.accessibilityHidden(true)
    }
}
