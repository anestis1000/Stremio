import Foundation
struct MediaProbe: Sendable, Equatable {
    let format: String
    let duration: Double
    let streams: [String]
}
