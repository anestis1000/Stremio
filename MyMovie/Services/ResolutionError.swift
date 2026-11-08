import Foundation
enum ResolutionError: LocalizedError {
    case needsServer, unsupported
    var errorDescription: String? {
        switch self {
        case .needsServer: "This source needs a streaming service. Enter your Stremio service's reachable address below, then select the stream again. On iPhone, localhost refers to the phone, not your computer."
        case .unsupported: "This addon did not return a supported video URL or a valid torrent source. Try another stream."
        }
    }
}
