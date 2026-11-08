import Foundation
import Network

/// A token-protected loopback server. Sparse torrent bytes are never served until
/// libtorrent has verified every piece covering the requested chunk.
actor TorrentStreamServer {
    private let engine: NativeTorrentEngine
    private var listener: NWListener?
    private var port: UInt16?
    private var pendingStart: CheckedContinuation<UInt16, Error>?
    private var files: [String: Entry] = [:]
    private let queue = DispatchQueue(label: "stremio.torrent.http")
    private struct Entry: Sendable { let hash: String; let index: Int; let url: URL; let size: Int64 }
    init(engine: NativeTorrentEngine) { self.engine = engine }
    func url(hash: String, file: TorrentFile, local: URL) async throws -> URL {
        let port = try await start()
        let token = UUID().uuidString
        files[token] = Entry(hash: hash, index: file.index, url: local, size: file.bytes)
        return URL(string: "http://127.0.0.1:\(port)/\(token)/\(local.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "video")")!
    }
    private func start() async throws -> UInt16 {
        if let port { return port }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        self.listener = listener
        listener.newConnectionHandler = { connection in Task { await self.handle(connection) } }
        return try await withCheckedThrowingContinuation { continuation in
            pendingStart = continuation
            listener.stateUpdateHandler = { state in Task { await self.changed(state) } }
            listener.start(queue: queue)
        }
    }
    private func changed(_ state: NWListener.State) {
        switch state {
        case .ready:
            guard let value = listener?.port?.rawValue else { return }
            port = value; pendingStart?.resume(returning: value); pendingStart = nil
        case .failed(let error): pendingStart?.resume(throwing: error); pendingStart = nil; listener?.cancel(); listener = nil
        default: break
        }
    }
    private func receive(_ connection: NWConnection) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { data, _, complete, error in
                if let error { continuation.resume(throwing: error) }
                else if let data, !data.isEmpty { continuation.resume(returning: data) }
                else { continuation.resume(throwing: TorrentError.message(complete ? "Connection closed" : "Empty request")) }
            }
        }
    }
    private func send(_ data: Data, to connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            })
        }
    }
    private func handle(_ connection: NWConnection) async {
        connection.start(queue: queue)
        defer { connection.cancel() }
        do {
            var request = Data()
            while request.range(of: Data("\r\n\r\n".utf8)) == nil {
                request.append(try await receive(connection))
                guard request.count <= 16_384 else { return }
            }
            let lines = String(decoding: request, as: UTF8.self).components(separatedBy: "\r\n")
            let first = (lines.first ?? "").split(separator: " ")
            guard first.count >= 2, first[0] == "GET" || first[0] == "HEAD",
                  let token = first[1].split(separator: "/").first, let entry = files[String(token)] else {
                try await send(Data("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8), to: connection); return
            }
            let rangeHeader = lines.first { $0.lowercased().hasPrefix("range:") }.map { String($0.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
            guard let range = HTTPByteRange.parse(rangeHeader, size: entry.size) else {
                try await send(Data("HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */\(entry.size)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8), to: connection); return
            }
            let partial = rangeHeader != nil
            var header = "HTTP/1.1 \(partial ? "206 Partial Content" : "200 OK")\r\nAccept-Ranges: bytes\r\nContent-Type: application/octet-stream\r\nContent-Length: \(range.upperBound - range.lowerBound + 1)\r\nConnection: close\r\n"
            if partial { header += "Content-Range: bytes \(range.lowerBound)-\(range.upperBound)/\(entry.size)\r\n" }
            try await send(Data((header + "\r\n").utf8), to: connection)
            if first[0] == "HEAD" { return }
            var offset = range.lowerBound
            var handle: FileHandle?
            defer { try? handle?.close() }
            while offset <= range.upperBound {
                let length = min(Int64(128 * 1024), range.upperBound - offset + 1)
                try await engine.prioritize(entry.hash, file: entry.index, offset: offset, length: min(4 * 1024 * 1024, entry.size - offset))
                let deadline = Date().addingTimeInterval(90)
                while try await !engine.ready(entry.hash, file: entry.index, offset: offset, length: length) {
                    guard Date() < deadline else { return }
                    try await Task.sleep(for: .milliseconds(200))
                }
                if handle == nil { handle = try FileHandle(forReadingFrom: entry.url) }
                try handle?.seek(toOffset: UInt64(offset))
                guard let chunk = try handle?.read(upToCount: Int(length)), chunk.count == Int(length) else { return }
                try await send(chunk, to: connection); offset += length
            }
        } catch { /* Closing the socket reports interrupted or unavailable media to mpv. */ }
    }
}
