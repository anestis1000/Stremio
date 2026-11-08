import Foundation
struct PlaybackRequest: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let item: MediaItem?
    let videoID: String
    let title: String
    var startTime: Double = 0
    var subtitles: [MediaSubtitle] = []
    var headers: [String: String] = [:]
    var subtitleHints: SubtitleHints?
    var alternatives: [PlaybackQuality] = []
}
