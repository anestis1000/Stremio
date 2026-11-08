import Foundation
struct TorrentSnapshot: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let progress: Double
    let downloadRate: Int64
    let downloaded: Int64
    let total: Int64
    let peers: Int
    let paused: Bool
    let finished: Bool
    let metadata: Bool
    let error: String
    let files: [TorrentFile]
}
struct TorrentFile: Decodable, Identifiable, Sendable {
    let index: Int
    let path: String
    let bytes: Int64
    let downloaded: Int64
    var id: Int { index }
    var isVideo: Bool { ["mp4", "mkv", "webm", "mov", "avi", "m4v", "ts", "mpg", "mpeg"].contains(URL(fileURLWithPath: path).pathExtension.lowercased()) }
}
struct TorrentJob: Codable, Identifiable, Sendable {
    let id: String
    let source: String
    let isMagnet: Bool
    let directory: String
    var title: String
    var paused: Bool = false
}
enum TorrentError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): text } }
}
