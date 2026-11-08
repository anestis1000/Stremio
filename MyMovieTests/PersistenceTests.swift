import Foundation
import Testing
@testable import MyMovie

@MainActor struct PersistenceTests {
    @Test func libraryAndProgressSurviveRelaunchAndRemainDistinctByType() throws {
        let suite = "StremioTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppStore(defaults: defaults)
        let movie = MediaItem(id: "same", type: "movie", name: "Movie")
        let series = MediaItem(id: "same", type: "series", name: "Series")
        store.toggleLibrary(movie); store.toggleLibrary(series)
        store.saveProgress(item: series, videoID: "same:1:2", title: "Episode", url: URL(string: "https://example.com/video.m3u8")!, seconds: 40, duration: 100)
        let restored = AppStore(defaults: defaults)
        #expect(restored.library.count == 2)
        #expect(restored.progress.first?.seconds == 40)
        #expect(restored.progress.first?.videoID == "same:1:2")
        restored.toggleLibrary(movie)
        #expect(restored.library.map(\.type) == ["series"])
        restored.resetHistory()
        #expect(AppStore(defaults: defaults).progress.isEmpty)
    }
    @Test func invalidProgressDoesNotCorruptPersistence() {
        let suite = "StremioTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppStore(defaults: defaults)
        store.saveProgress(item: MediaItem(id: "1", type: "movie", name: "Test"), videoID: "1", title: "Test", url: URL(string: "https://example.com/v.mp4")!, seconds: .nan, duration: .infinity)
        #expect(store.progress.isEmpty)
    }
}
