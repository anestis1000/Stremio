import Foundation
struct AddonExtra: Codable, Hashable, Sendable {
    let name: String
    var isRequired: Bool?
    var options: [String]?
}
