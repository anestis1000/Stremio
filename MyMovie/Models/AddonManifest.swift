import Foundation
struct AddonManifest: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let version: String
    let name: String
    var description: String?
    let resources: [AddonResource]
    let types: [String]
    var idPrefixes: [String]?
    var catalogs: [AddonCatalog]?
    var logo: URL?
    var behaviorHints: AddonHints?
    func supports(_ resource: String, type: String, id: String) -> Bool {
        types.contains(type) && (idPrefixes == nil || idPrefixes!.contains { id.hasPrefix($0) }) && resources.contains { $0.supports(resource, type: type, id: id) }
    }
}
