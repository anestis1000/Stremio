import Foundation
struct MediaSubtitle: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let url: URL
    let lang: String
    var label: String?
}
