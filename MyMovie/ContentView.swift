import SwiftUI

struct ContentView: View {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                NavigationStack {
                    HomeView().toolbar { ToolbarItem(placement: .topBarLeading) { Button("Settings", systemImage: "gearshape") { showSettings = true } } }.navigationDestination(for: MediaItem.self) { DetailView(item: $0) }
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
            Tab("Downloads", systemImage: "arrow.down.circle") { NavigationStack { DownloadsView() } }
        }
        .tint(Theme.accent)
        .preferredColorScheme(store.appearance.colorScheme)
        .task { await store.downloads.start(); await store.bootstrap() }
        .sheet(isPresented: $showSettings) { NavigationStack { SettingsView().toolbar { Button("Done") { showSettings = false } } } }
        .onChange(of: scenePhase) { _, phase in Task { if phase == .background { await store.downloads.background() } else if phase == .active { await store.downloads.foreground() } } }
        .onOpenURL { url in
            if url.scheme == "magnet" { Task { do { _ = try await store.downloads.add(magnet: url.absoluteString) } catch { store.downloads.error = error.localizedDescription } } }
            else if url.isFileURL && url.pathExtension.lowercased() == "torrent" { Task { do { _ = try await store.downloads.add(torrent: url) } catch { store.downloads.error = error.localizedDescription } } }
            else { store.pendingAddonURL = url.absoluteString }
        }
        .fullScreenCover(item: $store.playback) { request in PlayerView(request: request) }
        .sheet(isPresented: $store.showOpenStream) { OpenStreamView() }
        .sheet(item: $store.pendingAddon) { request in InstallAddonView(initialURL: request.url) }
        .onChange(of: store.pendingAddonURL) { _, value in
            if let value { store.pendingAddon = AddonInstallRequest(url: value); store.pendingAddonURL = nil }
        }
        .environment(store)
    }
}
#Preview { ContentView() }
