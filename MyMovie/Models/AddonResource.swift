import Foundation
enum AddonResource: Codable, Hashable, Sendable {
    case name(String)
    case scoped(name: String, types: [String]?, idPrefixes: [String]?)
    private enum CodingKeys: String, CodingKey { case name, types, idPrefixes }
    init(from decoder: any Decoder) throws {
        if let name = try? decoder.singleValueContainer().decode(String.self) { self = .name(name) }
        else {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self = .scoped(name: try c.decode(String.self, forKey: .name), types: try c.decodeIfPresent([String].self, forKey: .types), idPrefixes: try c.decodeIfPresent([String].self, forKey: .idPrefixes))
        }
    }
    func encode(to encoder: any Encoder) throws {
        switch self {
        case .name(let name): var c = encoder.singleValueContainer(); try c.encode(name)
        case let .scoped(name, types, prefixes):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name); try c.encodeIfPresent(types, forKey: .types); try c.encodeIfPresent(prefixes, forKey: .idPrefixes)
        }
    }
    func supports(_ resource: String, type: String, id: String) -> Bool {
        switch self {
        case .name(let name): return name == resource
        case let .scoped(name, types, prefixes):
            return name == resource && (types == nil || types!.contains(type)) && (prefixes == nil || prefixes!.contains { id.hasPrefix($0) })
        }
    }
}
