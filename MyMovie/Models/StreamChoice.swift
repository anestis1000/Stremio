import Foundation
struct StreamChoice: Identifiable, Sendable {
    let id: String
    let addonName: String
    let stream: MediaStream
}
