import SwiftUI
struct AddonRow: View {
    let addon: InstalledAddon
    let installed: Bool
    let inspect: () -> Void
    var body: some View {
        Button(action: inspect) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "puzzlepiece.extension.fill").font(.title2).foregroundStyle(Theme.accent).frame(width: 40, height: 44)
                VStack(alignment: .leading, spacing: 7) {
                    HStack { Text(addon.manifest.name).font(.headline); Spacer(); if installed { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) } }
                    if let description = addon.manifest.description { Text(description).font(.subheadline).foregroundStyle(.secondary).lineLimit(3) }
                    Text("v\(addon.manifest.version) · \(addon.manifest.types.joined(separator: ", "))").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.vertical, 10)
        }.buttonStyle(.plain)
    }
}
