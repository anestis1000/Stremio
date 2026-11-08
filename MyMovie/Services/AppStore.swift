import Foundation
import Observation

@MainActor @Observable
final class AppStore {
    private(set) var addons: [InstalledAddon] = []
    private(set) var library: [MediaItem] = []
    private(set) var progress: [WatchProgress] = []
    private(set) var sources: [CatalogSource] = []
    var appearance: Appearance = .dark { didSet { persist() } }
    var streamingServer = "" { didSet { persist() } }
    var playback: PlaybackRequest?
    var showOpenStream = false
    var pendingAddonURL: String?
    var pendingAddon: AddonInstallRequest?
    var startupError: String?
    private(set) var isStarting = true
    let downloads = DownloadManager()
    let client: AddonClient
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var started = false
    init(defaults: UserDefaults = .standard, client: AddonClient = AddonClient()) {
        self.defaults = defaults; self.client = client
        if let data = defaults.data(forKey: "stremio.local.v1"), let snapshot = try? JSONDecoder().decode(LocalSnapshot.self, from: data) {
            addons = snapshot.addons; library = snapshot.library; progress = snapshot.progress
            appearance = snapshot.appearance; streamingServer = snapshot.streamingServer
        }
        rebuildSources()
    }
    func bootstrap() async {
        guard !started else { return }; started = true
        defer { isStarting = false }
        if addons.isEmpty {
            do { install(try await client.manifest(at: AddonClient.cinemeta)) }
            catch { startupError = error.localizedDescription }
        }
    }
    func retryBootstrap() async { started = false; startupError = nil; isStarting = true; await bootstrap() }
    func install(_ addon: InstalledAddon) {
        addons.removeAll { $0.id == addon.id || $0.manifest.id == addon.manifest.id }
        addons.append(addon); rebuildSources(); persist()
    }
    func removeAddon(_ addon: InstalledAddon) { addons.removeAll { $0.id == addon.id }; rebuildSources(); persist() }
    func contains(_ item: MediaItem) -> Bool { library.contains { $0.key == item.key } }
    func toggleLibrary(_ item: MediaItem) {
        if contains(item) { library.removeAll { $0.key == item.key } } else { library.insert(item, at: 0) }; persist()
    }
    func saveProgress(item: MediaItem, videoID: String, title: String, url: URL, seconds: Double, duration: Double, torrentHash: String? = nil, torrentFileIndex: Int? = nil, headers: [String: String] = [:]) {
        guard seconds.isFinite, duration.isFinite, duration > 0, seconds >= 0 else { return }
        progress.removeAll { $0.item.key == item.key && $0.videoID == videoID }
        progress.insert(WatchProgress(item: item, videoID: videoID, title: title, url: url, seconds: seconds, duration: duration, torrentHash: torrentHash, torrentFileIndex: torrentFileIndex, headers: headers, updatedAt: .now), at: 0)
        progress = Array(progress.prefix(200)); persist()
    }
    func removeProgress(_ entry: WatchProgress) { progress.removeAll { $0.id == entry.id }; persist() }
    func play(_ entry: WatchProgress) {
        Task {
            do {
                let url: URL
                if let hash = entry.torrentHash { url = try await downloads.playbackURL(hash: hash, index: entry.torrentFileIndex) }
                else { url = entry.url }
                playback = PlaybackRequest(url: url, item: entry.item, videoID: entry.videoID, title: entry.title, startTime: entry.seconds, headers: entry.headers ?? [:], torrentHash: entry.torrentHash, torrentFileIndex: entry.torrentFileIndex)
            } catch { downloads.error = error.localizedDescription }
        }
    }
    func play(url: URL, item: MediaItem?, videoID: String, title: String) {
        let saved = progress.first { $0.item.key == item?.key && $0.videoID == videoID }
        playback = PlaybackRequest(url: url, item: item, videoID: videoID, title: title, startTime: saved?.seconds ?? 0)
    }
    func resetHistory() { progress = []; persist() }
    private func rebuildSources() {
        sources = addons.flatMap { addon in
            (addon.manifest.catalogs ?? []).filter { catalog in !(catalog.extra ?? []).contains { $0.isRequired == true } }.map { CatalogSource(addon: addon, catalog: $0) }
        }
    }
    private func persist() {
        let snapshot = LocalSnapshot(addons: addons, library: library, progress: progress, appearance: appearance, streamingServer: streamingServer)
        if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: "stremio.local.v1") }
    }
}
