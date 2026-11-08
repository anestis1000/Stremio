import Foundation
struct CatalogRow: Identifiable {
    let source: CatalogSource
    let items: [MediaItem]
    var id: String { source.id }
}
