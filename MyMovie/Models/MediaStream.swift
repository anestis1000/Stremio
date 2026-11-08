import Foundation
struct MediaStream: Decodable, Hashable, Sendable {
    var name: String?
    var title: String?
    var description: String?
    var url: URL?
    var externalUrl: URL?
    var infoHash: String?
    var fileIdx: Int?
    var ytId: String?
    var subtitles: [MediaSubtitle]?
    var label: String { name ?? "Stream" }
    var detail: String { description ?? title ?? url?.host ?? "" }
}
