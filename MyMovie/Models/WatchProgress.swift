import Foundation
struct WatchProgress: Codable, Hashable, Identifiable {
    var id: String { item.key + ":" + videoID }
    let item: MediaItem
    let videoID: String
    let title: String
    let url: URL
    var seconds: Double
    var duration: Double
    var torrentHash: String?
    var torrentFileIndex: Int?
    var headers: [String: String]?
    var updatedAt: Date
    var fraction: Double { duration > 0 ? min(max(seconds / duration, 0), 1) : 0 }
}
