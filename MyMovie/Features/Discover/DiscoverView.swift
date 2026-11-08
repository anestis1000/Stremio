import SwiftUI
struct DiscoverView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedSource = ""
    @State private var genre = ""
    @State private var query = ""
    @State private var items: [MediaItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var canLoadMore = false
    @State private var offset = 0
    private var source: CatalogSource? { store.sources.first { $0.id == selectedSource } ?? store.sources.first }
    private var requestKey: String { (source?.id ?? "") + ":" + genre + ":" + query }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DiscoverFilters(sources: store.sources, selectedSource: $selectedSource, genre: $genre, genres: source?.genres ?? [])
                if !items.isEmpty { MediaGrid(items: items) }
                if loading { ProgressView("Loading titles…").frame(maxWidth: .infinity).padding(30) }
                if let error { FailureView(message: error) { Task { await load(reset: true) } } }
                if !loading && items.isEmpty && error == nil {
                    ContentUnavailableView(query.isEmpty ? "No titles here yet" : "No results for “\(query)”", systemImage: "magnifyingglass", description: Text("Try a different catalog, genre, or search."))
                }
                if canLoadMore && !loading { Button("Load more") { Task { await load(reset: false) } }.frame(maxWidth: .infinity).buttonStyle(.bordered) }
            }.padding(20)
        }
        .background(Theme.background).navigationTitle("Discover")
        .searchable(text: $query, prompt: "Movies, series, and more")
        .task(id: requestKey) {
            do { try await Task.sleep(for: .milliseconds(query.isEmpty ? 0 : 350)) } catch { return }
            await load(reset: true)
        }
        .onChange(of: selectedSource) { genre = "" }
        .refreshable { await load(reset: true) }
    }
    private func load(reset: Bool) async {
        guard let source else { return }
        let key = requestKey
        if reset { items = []; offset = 0 }
        loading = true; error = nil
        do {
            let fetched: [MediaItem]
            if !query.isEmpty {
                var results: [MediaItem] = []
                for candidate in store.sources where candidate.catalog.supports("search") {
                    do { results += try await store.client.catalog(candidate, search: query) }
                    catch is CancellationError { throw CancellationError() }
                    catch { if results.isEmpty { self.error = error.localizedDescription } }
                }
                fetched = results
            } else { fetched = try await store.client.catalog(source, genre: genre, skip: offset) }
            try Task.checkCancellation()
            guard key == requestKey else { return }
            var seen = Set(items.map(\.key)); items += fetched.filter { seen.insert($0.key).inserted }
            offset += fetched.count
            canLoadMore = query.isEmpty && source.catalog.supports("skip") && fetched.count >= 100
            if !fetched.isEmpty { error = nil }
        } catch is CancellationError { return }
        catch { if key == requestKey { self.error = error.localizedDescription } }
        if key == requestKey { loading = false }
    }
}
