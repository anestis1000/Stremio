import Foundation
struct PlaybackRequest: Identifiable {
    let id = UUID()
    let url: URL
    let item: MediaItem?
    let videoID: String
    let title: String
    var startTime: Double = 0
}
