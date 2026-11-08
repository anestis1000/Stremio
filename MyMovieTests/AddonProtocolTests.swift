import Foundation
import Testing
@testable import MyMovie

struct AddonProtocolTests {
    @Test func nestedManifestPreservesConfigurationAndEncodesExtras() throws {
        let manifest = URL(string: "https://example.com/user-key/manifest.json")!
        let url = try AddonClient.resourceURL(manifest: manifest, resource: "catalog", type: "series", id: "my/catalog", extras: [("search", "A & B/Ω"), ("skip", "100")])
        #expect(url.absoluteString == "https://example.com/user-key/catalog/series/my%2Fcatalog/search=A%20%26%20B%2F%CE%A9&skip=100.json")
        #expect(url.query == nil)
    }
    @Test func resourceScopesRespectTypesAndPrefixes() throws {
        let data = Data(#"{"id":"test","version":"1.0.0","name":"Test","types":["movie","series"],"resources":["catalog",{"name":"stream","types":["series"],"idPrefixes":["tt"]}]}"#.utf8)
        let manifest = try JSONDecoder().decode(AddonManifest.self, from: data)
        #expect(manifest.supports("stream", type: "series", id: "tt123:1:2"))
        #expect(!manifest.supports("stream", type: "movie", id: "tt123"))
        #expect(!manifest.supports("stream", type: "series", id: "other"))
        let restored = try JSONDecoder().decode(AddonManifest.self, from: JSONEncoder().encode(manifest))
        #expect(restored == manifest)
    }
    @Test func deepLinksNormalizeAndRejectInvalidEndpoints() throws {
        #expect(try AddonClient.manifestURL(from: "stremio://example.com/config/manifest.json").scheme == "https")
        #expect(throws: ClientError.self) { try AddonClient.manifestURL(from: "https://example.com/configure") }
        #expect(throws: ClientError.self) { try AddonClient.manifestURL(from: "file:///manifest.json") }
    }
    @Test func episodeIdentityIsNotTheSeriesIdentity() throws {
        let data = Data(#"{"meta":{"id":"tt123","type":"series","name":"Show","videos":[{"id":"tt123:2:7","name":"Seven","season":2,"number":7}]}}"#.utf8)
        let response = try JSONDecoder().decode(MetaResponse.self, from: data)
        #expect(response.meta?.videos?.first?.id == "tt123:2:7")
        #expect(response.meta?.videos?.first?.episodeNumber == 7)
    }
}
