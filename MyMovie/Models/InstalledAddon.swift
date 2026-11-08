import Foundation
struct InstalledAddon: Codable, Hashable, Identifiable, Sendable {
    let transportUrl: URL
    let manifest: AddonManifest
    var id: String { transportUrl.absoluteString }
}
