import Foundation
struct MediaItem: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let type: String
    let name: String
    var poster: URL?
    var background: URL?
    var logo: URL?
    var description: String?
    var releaseInfo: String?
    var year: String?
    var runtime: String?
    var imdbRating: String?
    var genres: [String]?
    var cast: [String]?
    var videos: [MediaVideo]?
    var key: String { type + ":" + id }
    var yearLabel: String { releaseInfo ?? year ?? "" }
}
