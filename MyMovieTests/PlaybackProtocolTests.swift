import Foundation
import Testing
@testable import MyMovie
struct PlaybackProtocolTests {
    @Test func byteRangesSupportSeekingAndRejectMalformedRequests() {
        #expect(HTTPByteRange.parse(nil, size: 100) == 0...99)
        #expect(HTTPByteRange.parse("bytes=20-40", size: 100) == 20...40)
        #expect(HTTPByteRange.parse("bytes=90-", size: 100) == 90...99)
        #expect(HTTPByteRange.parse("bytes=-10", size: 100) == 90...99)
        #expect(HTTPByteRange.parse("bytes=90-200", size: 100) == 90...99)
        #expect(HTTPByteRange.parse("bytes=100-", size: 100) == nil)
        #expect(HTTPByteRange.parse("bytes=30-20", size: 100) == nil)
        #expect(HTTPByteRange.parse("bytes=0-5,10-15", size: 100) == nil)
        #expect(HTTPByteRange.parse("bytes=-0", size: 100) == nil)
        #expect(HTTPByteRange.parse(nil, size: 0) == nil)
    }
    @Test func hlsVariantsKeepHeadersAndResolveRelativeURLs() {
        let text = """
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=640x360
        low/index.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=4000000,RESOLUTION=1920x1080,AUDIO="audio"
        high/index.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=640x360
        low/index.m3u8
        """
        let result = HLSPlaylist.variants(text: text, baseURL: URL(string: "https://example.com/movie/master.m3u8")!, headers: ["Authorization": "Bearer test"])
        #expect(result.count == 1)
        #expect(result.first?.url.absoluteString == "https://example.com/movie/low/index.m3u8")
        #expect(result.first?.headers["Authorization"] == "Bearer test")
    }
    @Test func addonStreamPreservesPlaybackMetadata() throws {
        let json = #"{"streams":[{"infoHash":"0123456789012345678901234567890123456789","fileIdx":2,"sources":["tracker:https://example.com/announce"],"subtitles":[{"id":"en","url":"https://example.com/en.srt","lang":"eng"}],"behaviorHints":{"filename":"movie.mkv","videoHash":"abc","videoSize":100,"proxyHeaders":{"request":{"Referer":"https://example.com"}}}}]}"#
        let response = try JSONDecoder().decode(StreamsResponse.self, from: Data(json.utf8))
        let stream = try #require(response.streams?.first)
        #expect(stream.fileIdx == 2)
        #expect(stream.sources?.count == 1)
        #expect(stream.subtitles?.first?.lang == "eng")
        #expect(stream.behaviorHints?.proxyHeaders?.request?["Referer"] == "https://example.com")
    }
}
