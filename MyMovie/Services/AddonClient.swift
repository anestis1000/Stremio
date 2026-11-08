import Foundation
struct AddonClient: Sendable {
    static let cinemeta = URL(string: "https://v3-cinemeta.strem.io/manifest.json")!
    let session: URLSession
    init(session: URLSession = .shared) { self.session = session }
    func manifest(at url: URL) async throws -> InstalledAddon {
        let manifest: AddonManifest = try await get(url)
        guard !manifest.id.isEmpty, !manifest.resources.isEmpty, !manifest.types.isEmpty else { throw ClientError.invalidManifest }
        return InstalledAddon(transportUrl: url, manifest: manifest)
    }
    static func manifestURL(from text: String) throws -> URL {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "stremio://", with: "https://")
        guard let url = URL(string: text), url.scheme == "https", url.host != nil,
              url.path.hasSuffix("/manifest.json"), url.query == nil, url.fragment == nil else { throw ClientError.invalidURL }
        return url
    }
    static func resourceURL(manifest: URL, resource: String, type: String, id: String, extras: [(String, String)] = []) throws -> URL {
        guard manifest.path.hasSuffix("/manifest.json") else { throw ClientError.invalidURL }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")
        func encode(_ value: String) -> String { value.addingPercentEncoding(withAllowedCharacters: allowed)! }
        guard var components = URLComponents(url: manifest, resolvingAgainstBaseURL: false) else { throw ClientError.invalidURL }
        let base = String(components.percentEncodedPath.dropLast("manifest.json".count))
        let extra = extras.isEmpty ? "" : "/" + extras.map { encode($0.0) + "=" + encode($0.1) }.joined(separator: "&")
        components.percentEncodedPath = base + [resource, type, id].map(encode).joined(separator: "/") + extra + ".json"
        guard let url = components.url else { throw ClientError.invalidURL }; return url
    }
    func catalog(_ source: CatalogSource, search: String = "", genre: String = "", skip: Int = 0) async throws -> [MediaItem] {
        var extras: [(String, String)] = []
        if !search.isEmpty { extras.append(("search", search)) }
        if !genre.isEmpty { extras.append(("genre", genre)) }
        if source.catalog.supports("skip") { extras.append(("skip", String(skip))) }
        let url = try Self.resourceURL(manifest: source.addon.transportUrl, resource: "catalog", type: source.catalog.type, id: source.catalog.id, extras: extras)
        let response: CatalogResponse = try await get(url); return response.metas ?? []
    }
    func metadata(_ item: MediaItem, from addon: InstalledAddon) async throws -> MediaItem {
        let url = try Self.resourceURL(manifest: addon.transportUrl, resource: "meta", type: item.type, id: item.id)
        let response: MetaResponse = try await get(url)
        guard let meta = response.meta else { throw ClientError.emptyMetadata }; return meta
    }
    func streams(type: String, videoID: String, addon: InstalledAddon) async throws -> [MediaStream] {
        let url = try Self.resourceURL(manifest: addon.transportUrl, resource: "stream", type: type, id: videoID)
        let response: StreamsResponse = try await get(url); return response.streams ?? []
    }
    func directory(community: Bool) async throws -> [InstalledAddon] {
        let url = try Self.resourceURL(manifest: Self.cinemeta, resource: "addon_catalog", type: "all", id: community ? "community" : "official")
        let response: AddonsResponse = try await get(url); return response.addons ?? []
    }
    func subtitles(type: String, videoID: String, hints: SubtitleHints?, addon: InstalledAddon) async throws -> [MediaSubtitle] {
        var extras: [(String, String)] = []
        if let hash = hints?.videoHash { extras.append(("videoHash", hash)) }
        if let size = hints?.videoSize, size.isFinite { extras.append(("videoSize", String(format: "%.0f", size))) }
        if let filename = hints?.filename { extras.append(("filename", filename)) }
        let url = try Self.resourceURL(manifest: addon.transportUrl, resource: "subtitles", type: type, id: videoID, extras: extras)
        let response: SubtitleResponse = try await get(url)
        return response.subtitles ?? []
    }
    func get<T: Decodable & Sendable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url); request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { throw ClientError.http((response as? HTTPURLResponse)?.statusCode ?? 0) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
