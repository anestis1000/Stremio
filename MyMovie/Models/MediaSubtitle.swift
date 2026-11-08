import Foundation
struct MediaSubtitle: Decodable, Hashable, Sendable {
    let id: String
    let url: URL
    let lang: String
    var label: String?
}
