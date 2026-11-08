import Foundation
enum StreamResolver {
    static func playableURL(for stream: MediaStream, server: String) throws -> URL {
        if let url = stream.url {
            guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw ResolutionError.unsupported }
            return url
        }
        guard let hash = stream.infoHash, hash.count == 40, hash.allSatisfy(\.isHexDigit) else { throw ResolutionError.unsupported }
        guard let server = URL(string: server.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(server.scheme ?? ""), server.host != nil else { throw ResolutionError.needsServer }
        let url = server.appendingPathComponent(hash.lowercased()).appendingPathComponent(String(stream.fileIdx ?? -1))
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if let sources = stream.sources, !sources.isEmpty {
            components.queryItems = (components.queryItems ?? []) + sources.map { URLQueryItem(name: "tr", value: $0) }
        }
        guard let result = components.url else { throw ResolutionError.unsupported }
        return result
    }
}
