import Foundation
struct LocalSnapshot: Codable {
    let addons: [InstalledAddon]
    let library: [MediaItem]
    let progress: [WatchProgress]
    let appearance: Appearance
    let streamingServer: String
}
