import Foundation
import Observation

@MainActor @Observable
final class DownloadManager {
    private(set) var jobs: [TorrentJob] = []
    private(set) var snapshots: [TorrentSnapshot] = []
    var error: String?
    let engine = NativeTorrentEngine()
    @ObservationIgnored private var poller: Task<Void, Never>?
    @ObservationIgnored private var server: TorrentStreamServer?
    @ObservationIgnored private var started = false
    private let storage = URL.applicationSupportDirectory.appendingPathComponent("downloads.json")
    private let root = URL.documentsDirectory.appendingPathComponent("Downloads", isDirectory: true)
    init() {
        if let data = try? Data(contentsOf: storage), let saved = try? JSONDecoder().decode([TorrentJob].self, from: data) { jobs = saved }
    }
    func start() async {
        guard !started else { return }; started = true
        for job in jobs {
            do {
                _ = try await engine.add(source: job.source, magnet: job.isMagnet, directory: directory(job))
                if job.paused { try await engine.pause(job.id, paused: true) }
            } catch { self.error = error.localizedDescription }
        }
        poller = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do { self.snapshots = try await self.engine.snapshots() }
                catch { self.error = error.localizedDescription }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    func add(magnet: String, title: String = "Torrent") async throws -> String {
        guard URL(string: magnet)?.scheme?.lowercased() == "magnet" else { throw TorrentError.message("Enter a magnet link.") }
        return try await add(source: magnet, magnet: true, title: title)
    }
    func add(torrent: URL) async throws -> String {
        let access = torrent.startAccessingSecurityScopedResource()
        defer { if access { torrent.stopAccessingSecurityScopedResource() } }
        let inputs = URL.applicationSupportDirectory.appendingPathComponent("TorrentInputs", isDirectory: true)
        try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
        let local = inputs.appendingPathComponent(UUID().uuidString + ".torrent")
        try FileManager.default.copyItem(at: torrent, to: local)
        do { return try await add(source: local.path, magnet: false, title: torrent.deletingPathExtension().lastPathComponent) }
        catch { try? FileManager.default.removeItem(at: local); throw error }
    }
    private func add(source: String, magnet: Bool, title: String) async throws -> String {
        await start()
        let folder = UUID().uuidString
        let destination = root.appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        var excluded = destination; try excluded.setResourceValues(values)
        do {
            let hash = try await engine.add(source: source, magnet: magnet, directory: destination)
            if !jobs.contains(where: { $0.id == hash }) {
                jobs.insert(TorrentJob(id: hash, source: source, isMagnet: magnet, directory: folder, title: title), at: 0)
            } else { try? FileManager.default.removeItem(at: destination) }
            persist(); snapshots = try await engine.snapshots(); return hash
        } catch { try? FileManager.default.removeItem(at: destination); throw error }
    }
    func add(stream: MediaStream, title: String) async throws -> String {
        guard let hash = stream.infoHash, hash.count == 40, hash.allSatisfy({ $0.isHexDigit }) else { throw TorrentError.message("The addon returned an invalid torrent hash.") }
        var parts = URLComponents(); parts.scheme = "magnet"
        var query = [URLQueryItem(name: "xt", value: "urn:btih:" + hash), URLQueryItem(name: "dn", value: title)]
        for source in stream.sources ?? [] {
            let value = source.hasPrefix("tracker:") ? String(source.dropFirst(8)) : source
            if ["http", "https", "udp"].contains(URL(string: value)?.scheme ?? "") { query.append(URLQueryItem(name: "tr", value: value)) }
        }
        parts.queryItems = query
        guard let magnet = parts.string else { throw TorrentError.message("Cannot construct a torrent link.") }
        return try await add(magnet: magnet, title: title)
    }
    func snapshot(_ hash: String) -> TorrentSnapshot? { snapshots.first { $0.id == hash } }
    func directory(_ job: TorrentJob) -> URL { root.appendingPathComponent(job.directory, isDirectory: true) }
    func localFile(hash: String, file: TorrentFile) throws -> URL {
        guard let job = jobs.first(where: { $0.id == hash }) else { throw TorrentError.message("Download not found.") }
        let folder = directory(job).resolvingSymlinksInPath().standardizedFileURL
        let fileURL = folder.appendingPathComponent(file.path).resolvingSymlinksInPath().standardizedFileURL
        guard fileURL.path.hasPrefix(folder.path + "/") else { throw TorrentError.message("Unsafe torrent file path.") }
        return fileURL
    }
    func playbackURL(hash: String, index: Int? = nil) async throws -> URL {
        let deadline = Date().addingTimeInterval(120)
        var snapshot: TorrentSnapshot?
        repeat {
            try Task.checkCancellation()
            snapshot = try await engine.snapshots().first { $0.id == hash }
            if snapshot?.metadata == true { break }
            if let snapshot, !snapshot.error.isEmpty { throw TorrentError.message(snapshot.error) }
            guard Date() < deadline else { throw TorrentError.message("Torrent metadata is still unavailable. Check peers in Downloads and try again.") }
            try await Task.sleep(for: .milliseconds(300))
        } while true
        guard let snapshot else { throw TorrentError.message("Download no longer exists.") }
        let file = index.flatMap { chosen in snapshot.files.first { $0.index == chosen } } ?? snapshot.files.filter(\.isVideo).max { $0.bytes < $1.bytes }
        guard let file, file.isVideo else { throw TorrentError.message("Select a video file from this torrent in Downloads.") }
        try await engine.select(hash, file: file.index)
        let local = try localFile(hash: hash, file: file)
        if try await engine.ready(hash, file: file.index, offset: 0, length: file.bytes) { return local }
        if server == nil { server = TorrentStreamServer(engine: engine) }
        return try await server!.url(hash: hash, file: file, local: local)
    }
    func pause(_ job: TorrentJob) async {
        do {
            try await engine.pause(job.id, paused: !job.paused)
            if let index = jobs.firstIndex(where: { $0.id == job.id }) { jobs[index].paused.toggle() }
            persist(); snapshots = try await engine.snapshots(); await engine.save()
        } catch { self.error = error.localizedDescription }
    }
    func remove(_ job: TorrentJob) async {
        do {
            try await engine.remove(job.id)
            // Removing from the session keeps downloaded bytes; delete only this app-owned directory.
            let folder = directory(job)
            try? FileManager.default.removeItem(at: folder)
            if !job.isMagnet { try? FileManager.default.removeItem(atPath: job.source) }
            jobs.removeAll { $0.id == job.id }; snapshots.removeAll { $0.id == job.id }; persist()
        } catch { self.error = error.localizedDescription }
    }
    func background() async {
        for job in jobs { try? await engine.pause(job.id, paused: true) }
        await engine.save(); persist()
    }
    func foreground() async {
        for job in jobs where !job.paused { try? await engine.pause(job.id, paused: false) }
    }
    private func persist() {
        do {
            try FileManager.default.createDirectory(at: storage.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(jobs).write(to: storage, options: .atomic)
        } catch { self.error = error.localizedDescription }
    }
}
