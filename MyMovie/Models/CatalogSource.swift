import Foundation
struct CatalogSource: Hashable, Identifiable, Sendable {
    let addon: InstalledAddon
    let catalog: AddonCatalog
    var id: String { addon.id + ":" + catalog.type + ":" + catalog.id }
    var title: String { catalog.name ?? catalog.id.capitalized }
    var displayType: String { catalog.type == "series" ? "Series" : catalog.type.capitalized + "s" }
    var genres: [String] { catalog.extra?.first { $0.name == "genre" }?.options ?? catalog.genres ?? [] }
}
