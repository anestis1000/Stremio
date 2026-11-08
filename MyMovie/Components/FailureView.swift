import SwiftUI
struct FailureView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label("Couldn't load content", systemImage: "wifi.exclamationmark")
        } description: { Text(message) } actions: {
            Button("Try again", action: retry).buttonStyle(.borderedProminent)
        }
    }
}
