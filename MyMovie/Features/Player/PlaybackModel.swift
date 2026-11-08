import AVFAudio
import QuartzCore
import Libmpv
import Observation

@MainActor @Observable
final class PlaybackModel {
    var error: String?
    var notice: String?
    var loading = true
    var buffering = false
    var paused = false
    var ended = false
    var position = 0.0
    var duration = 0.0
    var cacheSeconds = 0.0
    var rate = 1.0
    var volume = 100.0
    var subtitleDelay = 0.0
    var audioDelay = 0.0
    var subtitleScale = 1.0
    var subtitlePosition = 100.0
    var useASSStyling = true
    var audioTracks: [PlaybackTrack] = []
    var subtitleTracks: [PlaybackTrack] = []
    var selectedAudio: Int64 = 0
    var selectedSubtitle: Int64 = 0
    var availableSubtitles: [MediaSubtitle] = []
    var loadingSubtitles = false
    var qualities: [PlaybackQuality] = []
    var selectedQuality = ""
    var videoDescription = ""
    var subtitleFailures: [String] = []
    @ObservationIgnored private var context: OpaquePointer?
    @ObservationIgnored private var poller: Task<Void, Never>?
    @ObservationIgnored private var subtitleTask: Task<Void, Never>?
    @ObservationIgnored private var subtitleFiles: [URL] = []
    @ObservationIgnored private var request: PlaybackRequest?
    @ObservationIgnored private weak var store: AppStore?
    @ObservationIgnored private var resumeAt = 0.0
    @ObservationIgnored private var ticks = 0
    @ObservationIgnored private var loadedURL: URL?

    func attach(to layer: CAMetalLayer) {
        guard context == nil else { return }
        guard let mpv = mpv_create() else { error = "The video engine could not be created."; return }
        context = mpv
        var windowID = Int64(Int(bitPattern: Unmanaged.passUnretained(layer).toOpaque()))
        mpv_set_option(mpv, "wid", MPV_FORMAT_INT64, &windowID)
        for (key, value) in [("vo", "gpu-next"), ("gpu-api", "vulkan"), ("gpu-context", "moltenvk"),
                             ("hwdec", "videotoolbox"), ("keep-open", "yes"), ("idle", "yes"),
                             ("terminal", "no"), ("osc", "no"), ("input-default-bindings", "no"),
                             ("cache", "yes"), ("demuxer-max-bytes", "128MiB"), ("network-timeout", "30"),
                             ("subs-match-os-language", "yes"), ("sub-auto", "fuzzy")] {
            mpv_set_option_string(mpv, key, value)
        }
        let result = mpv_initialize(mpv)
        guard result >= 0 else {
            error = "Video engine initialization failed: " + String(cString: mpv_error_string(result))
            mpv_terminate_destroy(mpv); context = nil; loading = false; return
        }
        poller = Task { [weak self] in
            while !Task.isCancelled {
                self?.poll()
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            }
        }
        loadIfReady()
    }

    func start(_ request: PlaybackRequest, store: AppStore) {
        self.request = request; self.store = store
        availableSubtitles = request.subtitles
        qualities = [PlaybackQuality(title: "Original / Auto", url: request.url, headers: request.headers)] + request.alternatives.filter { $0.url != request.url }
        selectedQuality = request.url.absoluteString
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { notice = error.localizedDescription }
        loadIfReady()
    }

    private func loadIfReady() {
        guard context != nil, let request, loadedURL == nil else { return }
        load(url: request.url, headers: request.headers, resume: request.startTime)
    }

    private func load(url: URL, headers: [String: String], resume: Double) {
        save(); subtitleTask?.cancel()
        mpv_abort_async_command(context, 2)
        loading = true; error = nil; ended = false; resumeAt = resume
        loadedURL = url
        set("http-header-fields", value: headers.sorted { $0.key < $1.key }.map { $0.key + ": " + $0.value }.joined(separator: ","))
        command(["loadfile", url.isFileURL ? url.path : url.absoluteString, "replace"])
    }

    func poll() {
        guard let context else { return }
        for _ in 0..<100 {
            guard let event = mpv_wait_event(context, 0), event.pointee.event_id != MPV_EVENT_NONE else { break }
            switch event.pointee.event_id {
            case MPV_EVENT_FILE_LOADED:
                loading = false
                if resumeAt > 0 { seek(resumeAt); resumeAt = 0 }
                set("pause", value: "no")
                refreshTracks()
            case MPV_EVENT_END_FILE:
                if let raw = event.pointee.data {
                    let end = raw.assumingMemoryBound(to: mpv_event_end_file.self).pointee
                    if end.reason == MPV_END_FILE_REASON_ERROR {
                        error = "This source could not be played: " + String(cString: mpv_error_string(end.error))
                    } else if end.reason == MPV_END_FILE_REASON_EOF { ended = true; save() }
                }
                loading = false
            case MPV_EVENT_COMMAND_REPLY:
                if event.pointee.error < 0 {
                    notice = String(cString: mpv_error_string(event.pointee.error))
                }
            default: break
            }
        }
        position = max(0, number("time-pos")); duration = max(0, number("duration"))
        paused = flag("pause"); buffering = flag("paused-for-cache"); cacheSeconds = max(0, number("demuxer-cache-duration"))
        ticks += 1
        if ticks % 4 == 0 { refreshTracks() }
        if ticks % 20 == 0 { save() }
    }

    private func refreshTracks() {
        let count = min(integer("track-list/count"), 100)
        var audio: [PlaybackTrack] = [], subtitles: [PlaybackTrack] = []
        if count > 0 {
            for index in 0..<count {
                let prefix = "track-list/\(index)/"
                let type = string(prefix + "type") ?? ""
                let track = PlaybackTrack(id: integer(prefix + "id"), type: type, title: string(prefix + "title") ?? "",
                                          language: string(prefix + "lang"), codec: string(prefix + "codec"),
                                          channels: integer(prefix + "demux-channel-count"), external: flag(prefix + "external"))
                if type == "audio" { audio.append(track) }
                if type == "sub" { subtitles.append(track) }
            }
        }
        audioTracks = audio; subtitleTracks = subtitles
        selectedAudio = integer("aid"); selectedSubtitle = integer("sid")
        let width = integer("width"), height = integer("height")
        let codec = string("video-codec") ?? ""
        videoDescription = width > 0 ? "\(width) × \(height) · \(codec)" : codec
    }

    func togglePause() {
        if ended { seek(0); ended = false; set("pause", value: "no") }
        else { set("pause", value: paused ? "no" : "yes") }
        poll()
    }
    func seek(_ seconds: Double) { command(["seek", String(max(0, seconds)), "absolute+exact"]) }
    func skip(_ seconds: Double) { seek(min(max(0, position + seconds), duration > 0 ? duration : .greatestFiniteMagnitude)) }
    func selectAudio(_ id: Int64) { set("aid", value: id == 0 ? "no" : String(id)); selectedAudio = id }
    func selectSubtitle(_ id: Int64) { subtitleTask?.cancel(); set("sid", value: id == 0 ? "no" : String(id)); selectedSubtitle = id }
    func setRate(_ value: Double) { rate = value; set("speed", value: String(value)) }
    func setVolume(_ value: Double) { volume = value; set("volume", value: String(value)) }
    func setSubtitleDelay(_ value: Double) { subtitleDelay = value; set("sub-delay", value: String(value)) }
    func setAudioDelay(_ value: Double) { audioDelay = value; set("audio-delay", value: String(value)) }
    func setSubtitleScale(_ value: Double) { subtitleScale = value; set("sub-scale", value: String(value)) }
    func setSubtitlePosition(_ value: Double) { subtitlePosition = value; set("sub-pos", value: String(value)) }
    func setASSStyling(_ value: Bool) { useASSStyling = value; set("sub-ass-override", value: value ? "no" : "force") }
    func setFill(_ fill: Bool) { set("panscan", value: fill ? "1" : "0") }

    func selectQuality(_ quality: PlaybackQuality) {
        guard quality.id != selectedQuality else { return }
        selectedQuality = quality.id; load(url: quality.url, headers: quality.headers, resume: position)
    }

    func loadSubtitle(_ subtitle: MediaSubtitle) {
        subtitleTask?.cancel(); loadingSubtitles = true
        let mediaURL = loadedURL
        subtitleTask = Task { [weak self] in
            guard let self else { return }
            do {
                let file: URL
                if subtitle.url.isFileURL { file = subtitle.url }
                else {
                    let (data, response) = try await URLSession.shared.data(from: subtitle.url)
                    guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode), !data.isEmpty else { throw ClientError.emptyMetadata }
                    try Task.checkCancellation()
                    let ext = subtitle.url.pathExtension.isEmpty ? "srt" : subtitle.url.pathExtension
                    file = FileManager.default.temporaryDirectory.appendingPathComponent("subtitle-\(UUID().uuidString).\(ext)")
                    try data.write(to: file, options: .atomic); self.subtitleFiles.append(file)
                }
                try Task.checkCancellation()
                guard self.loadedURL == mediaURL, self.context != nil else { return }
                self.command(["sub-add", file.path, "select", subtitle.label ?? subtitle.lang, subtitle.lang], id: 2)
            } catch is CancellationError { }
            catch { self.notice = "Couldn't load subtitle: " + error.localizedDescription }
            self.loadingSubtitles = false
        }
    }
    func importSubtitle(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("subtitle-\(UUID().uuidString).\(url.pathExtension)")
            try FileManager.default.copyItem(at: url, to: copy); subtitleFiles.append(copy)
            let subtitle = MediaSubtitle(id: copy.absoluteString, url: copy, lang: "und", label: url.lastPathComponent)
            availableSubtitles.append(subtitle); loadSubtitle(subtitle)
        } catch { notice = error.localizedDescription }
    }

    func discoverOptions() async {
        guard let request else { return }
        if let item = request.item, let store {
            for addon in store.addons where addon.manifest.supports("subtitles", type: item.type, id: request.videoID) {
                do {
                    let results = try await store.client.subtitles(type: item.type, videoID: request.videoID, hints: request.subtitleHints, addon: addon)
                    try Task.checkCancellation()
                    var seen = Set(availableSubtitles.map(\.url))
                    availableSubtitles += results.filter { seen.insert($0.url).inserted }
                } catch is CancellationError { return }
                catch { subtitleFailures.append(addon.manifest.name + ": " + error.localizedDescription) }
            }
        }
        guard request.url.pathExtension.lowercased() == "m3u8" else { return }
        do {
            var req = URLRequest(url: request.url); req.timeoutInterval = 15
            request.headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
            let (data, response) = try await URLSession.shared.data(for: req)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode), let text = String(data: data, encoding: .utf8) else { return }
            let variants = HLSPlaylist.variants(text: text, baseURL: response.url ?? request.url, headers: request.headers)
            var seen = Set(qualities.map(\.id)); qualities += variants.filter { seen.insert($0.id).inserted }
        } catch { /* Playback still uses the master playlist if variant discovery fails. */ }
    }

    func background() { save(); set("pause", value: "yes"); set("vid", value: "no") }
    func foreground() { set("vid", value: "auto") }
    func save() {
        guard let request, let item = request.item, let url = loadedURL else { return }
        store?.saveProgress(item: item, videoID: request.videoID, title: request.title, url: url, seconds: position, duration: duration, torrentHash: request.torrentHash, torrentFileIndex: request.torrentFileIndex, headers: request.headers)
    }
    func stop() {
        save(); poller?.cancel(); poller = nil; subtitleTask?.cancel(); subtitleTask = nil
        if let context { mpv_abort_async_command(context, 0); mpv_terminate_destroy(context); self.context = nil }
        for file in subtitleFiles { try? FileManager.default.removeItem(at: file) }; subtitleFiles = []
        loadedURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func command(_ args: [String], id: UInt64 = 1) {
        guard let context else { return }
        let pointers = args.map { strdup($0) }
        defer { pointers.forEach { free($0) } }
        var cargs: [UnsafePointer<CChar>?] = pointers.map { $0.map { UnsafePointer($0) } } + [nil]
        let result = mpv_command_async(context, id, &cargs)
        if result < 0 { notice = String(cString: mpv_error_string(result)) }
    }
    private func set(_ name: String, value: String) { guard let context else { return }; mpv_set_property_string(context, name, value) }
    private func number(_ name: String) -> Double {
        guard let context else { return 0 }; var value = 0.0
        guard mpv_get_property(context, name, MPV_FORMAT_DOUBLE, &value) >= 0, value.isFinite else { return 0 }; return value
    }
    private func integer(_ name: String) -> Int64 {
        guard let context else { return 0 }; var value: Int64 = 0
        return mpv_get_property(context, name, MPV_FORMAT_INT64, &value) >= 0 ? value : 0
    }
    private func flag(_ name: String) -> Bool {
        guard let context else { return false }; var value: Int32 = 0
        return mpv_get_property(context, name, MPV_FORMAT_FLAG, &value) >= 0 && value != 0
    }
    private func string(_ name: String) -> String? {
        guard let context, let pointer = mpv_get_property_string(context, name) else { return nil }
        defer { mpv_free(pointer) }; return String(cString: pointer)
    }
}
