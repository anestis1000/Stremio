import Foundation
struct PlaybackTrack: Identifiable, Equatable {
    let id: Int64
    let type: String
    let title: String
    let language: String?
    let codec: String?
    let channels: Int64
    let external: Bool
    var label: String {
        var parts: [String] = []
        if !title.isEmpty { parts.append(title) }
        if let language, !language.isEmpty {
            parts.append(Locale.current.localizedString(forLanguageCode: language) ?? language)
        }
        if let codec, !codec.isEmpty { parts.append(codec.uppercased()) }
        if channels > 0 { parts.append("\(channels) ch") }
        return parts.isEmpty ? "Track \(id)" : parts.joined(separator: " · ")
    }
}
