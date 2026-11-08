import SwiftUI
struct DiscoverFilters: View {
    let sources: [CatalogSource]
    @Binding var selectedSource: String
    @Binding var genre: String
    let genres: [String]
    var body: some View {
        HStack {
            Menu {
                Picker("Catalog", selection: $selectedSource) {
                    ForEach(sources) { source in Text("\(source.title) · \(source.displayType) · \(source.addon.manifest.name)").tag(source.id) }
                }
            } label: { Label(sources.first { $0.id == selectedSource }?.title ?? sources.first?.title ?? "Catalog", systemImage: "square.grid.2x2") }
                .buttonStyle(.bordered)
            Spacer()
            Menu {
                Picker("Genre", selection: $genre) {
                    Text("All genres").tag("")
                    ForEach(genres, id: \.self) { Text($0).tag($0) }
                }
            } label: { Label(genre.isEmpty ? "All genres" : genre, systemImage: "line.3.horizontal.decrease") }
                .buttonStyle(.bordered).disabled(genres.isEmpty)
        }
    }
}
