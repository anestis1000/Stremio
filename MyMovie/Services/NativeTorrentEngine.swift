import Foundation
import NativeTorrent

/// All libtorrent calls run off the main actor, including resume-data flushing.
actor NativeTorrentEngine {
    private var context: UnsafeMutableRawPointer?
    private func engine() throws -> UnsafeMutableRawPointer {
        if let context { return context }
        let directory = URL.applicationSupportDirectory.appendingPathComponent("TorrentResume", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let created = st_session_create(directory.path) else { throw TorrentError.message("Could not start the native torrent engine.") }
        context = created; return created
    }
    private func data(_ pointer: UnsafeMutablePointer<CChar>?) throws -> Data {
        guard let pointer else { throw TorrentError.message("The torrent engine returned no response.") }
        defer { st_free_string(pointer) }
        let data = Data(String(cString: pointer).utf8)
        if let response = try? JSONDecoder().decode(Failure.self, from: data) { throw TorrentError.message(response.error) }
        return data
    }
    func add(source: String, magnet: Bool, directory: URL) throws -> String {
        let handle = try engine()
        let response = try data(magnet ? st_add_magnet(handle, source, directory.path) : st_add_file(handle, source, directory.path))
        return try JSONDecoder().decode(Added.self, from: response).id
    }
    func snapshots() throws -> [TorrentSnapshot] { try JSONDecoder().decode([TorrentSnapshot].self, from: data(st_snapshot(try engine()))) }
    func pause(_ hash: String, paused: Bool) throws { _ = try data(st_set_paused(try engine(), hash, paused ? 1 : 0)) }
    func remove(_ hash: String) throws { _ = try data(st_remove(try engine(), hash)) }
    func select(_ hash: String, file: Int) throws { _ = try data(st_select_file(try engine(), hash, Int32(file))) }
    func ready(_ hash: String, file: Int, offset: Int64, length: Int64) throws -> Bool {
        let result = st_range_ready(try engine(), hash, Int32(file), offset, length)
        if result < 0 { throw TorrentError.message("This torrent file is no longer available.") }; return result == 1
    }
    func prioritize(_ hash: String, file: Int, offset: Int64, length: Int64) throws { st_prioritize_range(try engine(), hash, Int32(file), offset, length) }
    func save() { if let context { st_save_resume(context) } }
    private struct Failure: Decodable { let error: String }
    private struct Added: Decodable { let id: String }
}
