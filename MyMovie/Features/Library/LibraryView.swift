import SwiftUI
struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var selection = "All"
    @State private var query = ""
    private var filtered: [MediaItem] {
        store.library.filter { (selection == "All" || $0.type == (selection == "Movies" ? "movie" : "series")) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Picker("Media type", selection: $selection) { Text("All").tag("All"); Text("Movies").tag("Movies"); Text("Series").tag("Series") }.pickerStyle(.segmented)
                if filtered.isEmpty {
                    ContentUnavailableView("A collection that's yours", systemImage: "square.stack", description: Text("Save a title to your library to find it here. Your collection is stored on this device."))
                } else { MediaGrid(items: filtered) }
            }.padding(20)
        }.background(Theme.background).navigationTitle("Library").searchable(text: $query, prompt: "Search your library")
    }
}
