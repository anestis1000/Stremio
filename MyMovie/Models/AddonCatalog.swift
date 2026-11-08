import Foundation
struct AddonCatalog: Codable, Hashable, Identifiable, Sendable {
    let type: String
    let id: String
    var name: String?
    var extra: [AddonExtra]?
    var extraSupported: [String]?
    var genres: [String]?
    func supports(_ value: String) -> Bool { extra?.contains { $0.name == value } == true || extraSupported?.contains(value) == true }
}
