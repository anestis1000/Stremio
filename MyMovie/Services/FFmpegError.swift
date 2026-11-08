import Foundation
enum FFmpegError: LocalizedError {
    case openFailed, noStreams
    var errorDescription: String? {
        switch self {
        case .openFailed: "FFmpeg could not open this local media file."
        case .noStreams: "FFmpeg could not find playable tracks in this file."
        }
    }
}
