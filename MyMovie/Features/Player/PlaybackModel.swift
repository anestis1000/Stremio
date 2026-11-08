import AVKit
import Observation

@MainActor @Observable
final class PlaybackModel {
    let player = AVPlayer()
    var error: String?
    var loading = true
    @ObservationIgnored private var observer: NSKeyValueObservation?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var request: PlaybackRequest?
    @ObservationIgnored private weak var store: AppStore?

    func start(_ request: PlaybackRequest, store: AppStore) {
        self.request = request; self.store = store
        do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback); try AVAudioSession.sharedInstance().setActive(true) }
        catch { self.error = error.localizedDescription }
        let item = AVPlayerItem(url: request.url)
        observer = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let ready = item.status == .readyToPlay
            let failed = item.status == .failed
            let failure = item.error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self else { return }
                if ready {
                    self.loading = false
                    if request.startTime > 0 { await self.player.seek(to: CMTime(seconds: request.startTime, preferredTimescale: 600)) }
                    self.player.play()
                } else if failed {
                    self.loading = false
                    self.error = failure ?? "This stream could not be opened. Try another source or a format supported by iOS."
                }
            }
        }
        player.replaceCurrentItem(with: item)
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 1), queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.save() }
        }
    }
    func save() {
        guard let request, let item = request.item, let duration = player.currentItem?.duration.seconds else { return }
        store?.saveProgress(item: item, videoID: request.videoID, title: request.title, url: request.url, seconds: player.currentTime().seconds, duration: duration)
    }
    func stop() {
        save(); player.pause(); observer = nil
        if let timeObserver { player.removeTimeObserver(timeObserver); self.timeObserver = nil }
        player.replaceCurrentItem(with: nil)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
