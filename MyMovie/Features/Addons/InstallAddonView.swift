import SwiftUI
struct InstallAddonView: View {
    let initialURL: String
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var addon: InstalledAddon?
    @State private var loading = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Manifest URL") {
                    TextField("https://your-addon.com/manifest.json", text: $address)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .onChange(of: address) { addon = nil; error = nil }
                    Button("Check addon") { Task { await inspect() } }.disabled(loading || address.isEmpty)
                }
                if loading { ProgressView("Reading manifest…") }
                if let error { Section { Text(error).font(.callout).foregroundStyle(.red) } }
                if let addon {
                    Section(addon.manifest.name) {
                        if let description = addon.manifest.description { Text(description) }
                        LabeledContent("Version", value: addon.manifest.version)
                        LabeledContent("Types", value: addon.manifest.types.joined(separator: ", "))
                        Text(addon.transportUrl.host ?? "").font(.footnote).foregroundStyle(.secondary)
                        if addon.manifest.behaviorHints?.configurable == true {
                            Link("Configure addon", destination: addon.transportUrl.deletingLastPathComponent().appendingPathComponent("configure"))
                        }
                        if addon.manifest.behaviorHints?.configurationRequired == true {
                            Text("Complete the provider's configuration and paste the resulting manifest URL before installing.").font(.callout)
                        } else {
                            Button(store.addons.contains { $0.manifest.id == addon.manifest.id } ? "Update installed addon" : "Install addon") {
                                store.install(addon); dismiss()
                            }.fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Install addon").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task { address = initialURL; if !initialURL.isEmpty { await inspect() } }
        }
    }
    private func inspect() async {
        loading = true; error = nil; addon = nil
        do {
            let url = try AddonClient.manifestURL(from: address)
            let fetched = try await store.client.manifest(at: url)
            try Task.checkCancellation(); addon = fetched
        } catch is CancellationError { return }
        catch { self.error = error.localizedDescription }
        loading = false
    }
}
