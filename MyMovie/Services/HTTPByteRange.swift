import Foundation
struct HTTPByteRange {
    static func parse(_ header: String?, size: Int64) -> ClosedRange<Int64>? {
        guard size > 0 else { return nil }
        guard let header else { return 0...(size - 1) }
        guard header.hasPrefix("bytes="), !header.contains(",") else { return nil }
        let parts = header.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        if parts[0].isEmpty {
            guard let suffix = Int64(parts[1]), suffix > 0 else { return nil }
            return max(0, size - suffix)...(size - 1)
        }
        guard let start = Int64(parts[0]), start >= 0, start < size else { return nil }
        let end: Int64
        if parts[1].isEmpty { end = size - 1 }
        else { guard let value = Int64(parts[1]), value >= start else { return nil }; end = min(value, size - 1) }
        return start...end
    }
}
