import Foundation
struct StreamRequest: Identifiable {
    var id: String { item.key + ":" + videoID }
    let item: MediaItem
    let videoID: String
    let title: String
}
