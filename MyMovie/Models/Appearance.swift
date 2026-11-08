import SwiftUI
enum Appearance: String, CaseIterable, Codable {
    case system = "System", dark = "Dark", light = "Light"
    var colorScheme: ColorScheme? { switch self { case .system: nil; case .dark: .dark; case .light: .light } }
}
