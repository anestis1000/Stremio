import SwiftUI
struct AddonsView: View {
    @Environment(AppStore.self) private var store
    @State private var directory: [InstalledAddon] = []
    @State private var selection = "Installed"
    @State private var query = ""
    @State private var installing: AddonInstallRequest?
    @State private var loading = false
    @State private var error: String?
    private var visible: [InstalledAddon] {
        (selection == "Installed" ? store.addons : directory).filter { query.isEmpty || $0.manifest.name.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        List {
            Section {
                Picker("Addon collection", selection: $selection) {
                    Text("Installed").tag("Installed"); Text("Official").tag("Official"); Text("Community").tag("Community")
                }.pickerStyle(.segmented).listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)).listRowBackground(Color.clear)
            }
            if loading { ProgressView("Loading addon directory…") }
            if let error { Section { Text(error).font(.callout).foregroundStyle(.secondary); Button("Try again") { Task { await load() } } } }
            ForEach(visible) { addon in
                AddonRow(addon: addon, installed: store.addons.contains { $0.manifest.id == addon.manifest.id }) {
                    installing = AddonInstallRequest(url: addon.transportUrl.absoluteString)
                }
                .swipeActions {
                    if selection == "Installed" { Button("Remove", role: .destructive) { store.removeAddon(addon) } }
                }
            }
            if visible.isEmpty && !loading && error == nil {
                ContentUnavailableView("No addons here", systemImage: "puzzlepiece.extension", description: Text("Browse the directory or install an addon using its manifest URL."))
            }
            if selection == "Installed" {
                Section { Text("Addons are remote services. Install only providers you trust and use sources you are authorized to access.").font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Addons").searchable(text: $query, prompt: "Search addons")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Install addon", systemImage: "plus") { installing = AddonInstallRequest(url: "") } } }
        .sheet(item: $installing) { InstallAddonView(initialURL: $0.url) }
        .task(id: selection) { await load() }
        .refreshable { await load() }
    }
    private func load() async {
        guard selection != "Installed" else { error = nil; loading = false; return }
        let selected = selection
        directory = []; loading = true; error = nil
        do {
            let result = try await store.client.directory(community: selected == "Community")
            try Task.checkCancellation()
            if selected == selection { directory = result }
        } catch is CancellationError { return }
        catch { if selected == selection { self.error = error.localizedDescription } }
        if selected == selection { loading = false }
    }
}
