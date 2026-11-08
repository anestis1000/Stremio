import Foundation
import Libavformat
import Libavcodec
import Libavutil

/// Calls the compiled FFmpeg libraries directly; no subprocess or remote probe.
actor NativeFFmpeg {
    static let shared = NativeFFmpeg()
    nonisolated static var version: String { String(cString: av_version_info()) }

    func probe(file: URL) throws -> MediaProbe {
        guard file.isFileURL else { throw FFmpegError.openFailed }
        var context: UnsafeMutablePointer<AVFormatContext>?
        guard avformat_open_input(&context, file.path, nil, nil) >= 0, let opened = context else { throw FFmpegError.openFailed }
        defer { avformat_close_input(&context) }
        guard avformat_find_stream_info(opened, nil) >= 0 else { throw FFmpegError.noStreams }
        var streams: [String] = []
        for index in 0..<Int(opened.pointee.nb_streams) {
            guard let stream = opened.pointee.streams[index], let parameters = stream.pointee.codecpar else { continue }
            let codec = String(cString: avcodec_get_name(parameters.pointee.codec_id))
            if parameters.pointee.codec_type == AVMEDIA_TYPE_VIDEO {
                streams.append("Video · \(codec) · \(parameters.pointee.width) × \(parameters.pointee.height)")
            } else if parameters.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
                streams.append("Audio · \(codec) · \(parameters.pointee.ch_layout.nb_channels) channels")
            } else if parameters.pointee.codec_type == AVMEDIA_TYPE_SUBTITLE {
                streams.append("Subtitles · \(codec)")
            }
        }
        let format = opened.pointee.iformat.flatMap { $0.pointee.long_name }.map { String(cString: $0) } ?? "Media"
        let duration = opened.pointee.duration > 0 ? Double(opened.pointee.duration) / Double(AV_TIME_BASE) : 0
        return MediaProbe(format: format, duration: duration, streams: streams)
    }
}
