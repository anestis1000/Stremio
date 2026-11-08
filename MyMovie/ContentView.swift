import SwiftUI

struct ContentView: View {
    @State private var store = AppStore()
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                NavigationStack {
                    HomeView().navigationDestination(for: MediaItem.self) { DetailView(item: $0) }
                }
            }
            Tab("Discover", systemImage: "safari") {
                NavigationStack {
                    DiscoverView().navigationDestination(for: MediaItem.self) { DetailView(item: $0) }
                }
            }
            Tab("Library", systemImage: "square.stack") {
                NavigationStack {
                    LibraryView().navigationDestination(for: MediaItem.self) { DetailView(item: $0) }
                }
            }
            Tab("Addons", systemImage: "puzzlepiece.extension") { NavigationStack { AddonsView() } }
            Tab("Settings", systemImage: "gearshape") { NavigationStack { SettingsView() } }
        }
        .tint(Theme.accent).environment(store)
        .preferredColorScheme(store.appearance.colorScheme)
        .task { await store.bootstrap() }
        .onOpenURL { store.pendingAddonURL = $0.absoluteString }
        .sheet(item: $store.playback) { request in PlayerView(request: request) }
        .sheet(isPresented: $store.showOpenStream) { OpenStreamView() }
        .sheet(item: $store.pendingAddon) { request in InstallAddonView(initialURL: request.url) }
        .onChange(of: store.pendingAddonURL) { _, value in
            if let value { store.pendingAddon = AddonInstallRequest(url: value); store.pendingAddonURL = nil }
        }
    }
}
#Preview { ContentView() }
