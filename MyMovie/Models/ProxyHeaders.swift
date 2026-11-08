import Foundation
struct ProxyHeaders: Decodable, Hashable, Sendable {
    var request: [String: String]?
    var response: [String: String]?
}
