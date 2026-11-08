import Foundation
struct PlaybackQuality: Identifiable, Hashable, Codable, Sendable {
    var id: String { url.absoluteString }
    let title: String
    let url: URL
    var headers: [String: String] = [:]
}
