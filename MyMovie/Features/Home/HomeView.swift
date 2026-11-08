import SwiftUI
struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var rows: [CatalogRow] = []
    @State private var isLoading = false
    @State private var error: String?
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                if let featured = rows.first?.items.first { FeaturedView(item: featured) }
                if store.progress.contains(where: { $0.fraction < 0.95 && $0.seconds > 5 }) { ContinueWatchingView() }
                ForEach(rows) { row in CatalogShelf(title: row.source.title + " · " + row.source.displayType, items: row.items) }
                if isLoading || store.isStarting { ProgressView("Finding your next watch…").frame(maxWidth: .infinity).padding(50) }
                if let message = error ?? store.startupError, rows.isEmpty {
                    FailureView(message: message) { Task { await store.retryBootstrap(); await load() } }
                }
                if !isLoading && !store.isStarting && rows.isEmpty && error == nil && store.startupError == nil {
                    ContentUnavailableView("Your home starts with addons", systemImage: "puzzlepiece.extension", description: Text("Install a catalog addon in the Addons tab."))
                }
            }.padding(.bottom, 28)
        }
        .background(Theme.background).navigationTitle("Stremio")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Open stream", systemImage: "play.rectangle.on.rectangle") { store.showOpenStream = true }
            }
        }
        .task(id: store.sources) { await load() }
        .refreshable { await load() }
    }
    private func load() async {
        guard !store.sources.isEmpty else { rows = []; return }
        isLoading = true; error = nil
        var loaded: [CatalogRow] = []
        var firstError: String?
        for source in store.sources.prefix(6) {
            do {
                let items = try await store.client.catalog(source)
                try Task.checkCancellation()
                if !items.isEmpty { loaded.append(CatalogRow(source: source, items: Array(items.prefix(20)))); rows = loaded }
            } catch is CancellationError { return }
            catch { firstError = firstError ?? error.localizedDescription }
        }
        guard !Task.isCancelled else { return }
        rows = loaded; error = firstError; isLoading = false
    }
}
