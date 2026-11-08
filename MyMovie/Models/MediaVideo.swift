import Foundation
struct MediaVideo: Codable, Hashable, Identifiable, Sendable {
    let id: String
    var title: String?
    var name: String?
    var season: Int?
    var episode: Int?
    var number: Int?
    var thumbnail: URL?
    var overview: String?
    var description: String?
    var released: String?
    var displayName: String { title ?? name ?? "Episode \(episode ?? number ?? 0)" }
    var episodeNumber: Int { episode ?? number ?? 0 }
}
