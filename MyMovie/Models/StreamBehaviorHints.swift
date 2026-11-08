import Foundation
struct StreamBehaviorHints: Decodable, Hashable, Sendable {
    var filename: String?
    var videoHash: String?
    var videoSize: Double?
    var proxyHeaders: ProxyHeaders?
}
