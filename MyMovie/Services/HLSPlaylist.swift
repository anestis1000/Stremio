import Foundation
enum HLSPlaylist {
    static func variants(text: String, baseURL: URL, headers: [String: String] = [:]) -> [PlaybackQuality] {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var pending: String?
        var variants: [PlaybackQuality] = []
        for line in lines {
            if line.hasPrefix("#EXT-X-STREAM-INF:") { pending = line; continue }
            guard !line.isEmpty, !line.hasPrefix("#"), let info = pending else { continue }
            pending = nil
            guard let url = URL(string: line, relativeTo: baseURL)?.absoluteURL, ["http", "https"].contains(url.scheme ?? "") else { continue }
            // An external audio group needs its master playlist to stay intact.
            if info.contains("AUDIO=") { continue }
            let resolution = info.range(of: #"RESOLUTION=\d+x(\d+)"#, options: .regularExpression).map { String(info[$0]).components(separatedBy: "x").last! + "p" }
            let bandwidth = info.range(of: #"BANDWIDTH=\d+"#, options: .regularExpression).flatMap { Double(info[$0].split(separator: "=").last!) }
            let title = resolution ?? bandwidth.map { String(format: "%.1f Mbps", $0 / 1_000_000) } ?? "Variant \(variants.count + 1)"
            variants.append(PlaybackQuality(title: title, url: url, headers: headers))
        }
        var seen = Set<String>()
        return variants.filter { seen.insert($0.id).inserted }
    }
}
