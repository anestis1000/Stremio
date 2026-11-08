import Foundation
enum ClientError: LocalizedError {
    case invalidURL, invalidManifest, emptyMetadata, http(Int)
    var errorDescription: String? {
        switch self {
        case .invalidURL: "Enter a complete HTTPS addon URL ending in /manifest.json."
        case .invalidManifest: "This addon manifest is missing its identity, resources, or content types."
        case .emptyMetadata: "This addon did not return details for this title."
        case .http(let status): "The addon returned HTTP \(status). Try again or choose another addon."
        }
    }
}
