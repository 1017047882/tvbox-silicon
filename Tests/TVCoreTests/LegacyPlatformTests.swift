import Foundation
import Testing
@testable import TVCore

@Test func legacyRegexPreservesUnicodeAndOriginalIndices() throws {
    let line = "中文🎬 URI=\"字幕/测试.m3u8\" end"
    let match = try #require(line.tvFirstMatch(#"URI="([^"]+)""#))
    #expect(match[1] == "字幕/测试.m3u8")
    #expect(line.replacingCharacters(in: match[1].startIndex..<match[1].endIndex, with: "local") == "中文🎬 URI=\"local\" end")
    let slice = line.dropFirst(2)
    let sliced = try #require(slice.tvFirstMatch(#"URI="([^"]+)""#))
    #expect(slice[sliced.range] == "URI=\"字幕/测试.m3u8\"")
    #expect(line[sliced[1].startIndex..<sliced[1].endIndex] == "字幕/测试.m3u8")
    #expect(line.tvFirstMatch("[") == nil)
}

@Test func legacyFirstRegexMatchKeepsFirstCapturesAndEmptyMatches() throws {
    let text = "中文🎬 first=一 second=二"
    let slice = text.dropFirst(2)
    let pattern = #"(first|second)=([^ ]+)"#
    let match = try #require(slice.tvFirstMatch(pattern))
    #expect(match[1] == "first")
    #expect(match[2] == "一")
    #expect(text[match.range] == "first=一")
    #expect(slice.tvMatches(pattern).count == 2)
    #expect(slice.tvFirstMatch("not-present") == nil)
    #expect(slice.tvFirstMatch("^")?[0] == "")
    #expect(slice.tvFirstMatch(#"(missing)?first"#)?[1] == "")
}

@Test func legacyQueryKeepsExistingItemsAndFragment() throws {
    let url = try #require(URL(string: "https://example.com/path?existing=a%26b#fragment"))
    let added = url.tvAppending(queryItems: [.init(name: "new", value: "中文+&")])
    let parts = try #require(URLComponents(url: added, resolvingAgainstBaseURL: false))
    #expect(parts.queryItems == [.init(name: "existing", value: "a&b"), .init(name: "new", value: "中文+&")])
    #expect(parts.fragment == "fragment")
}

@Test func legacyDelayRejectsInvalidValuesAndPropagatesCancellation() async throws {
    for value in [-1.0, Double.nan, .infinity, Double(UInt64.max)] {
        do {
            try await tvSleep(for: .seconds(value))
            Issue.record("Invalid delay accepted")
        } catch { #expect(!(error is CancellationError)) }
    }
    let sleeper = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        try await tvSleep(for: .seconds(30))
    }
    do {
        try await sleeper.value
        Issue.record("Cancelled delay completed")
    } catch { #expect(error is CancellationError) }
    #expect(TVDelay.milliseconds(350).seconds == 0.35)
}

@Test func legacyClockMeasuresMonotonicElapsedTime() {
    let start = TVInstant.now
    let end = TVInstant.now
    #expect(start <= end)
    #expect(start.duration(to: end).seconds >= 0)
    #expect(end.duration(to: start).seconds <= 0)
    #expect(start.duration(to: start + .seconds(5)).seconds > 4.99)
}

@Test func legacyPlaybackClockHandlesLongAndInvalidTimes() {
    #expect(TVDelay.seconds(0).clock() == "0:00")
    #expect(TVDelay.seconds(3661).clock(hours: true) == "1:01:01")
    #expect(TVDelay.seconds(3661).clock() == "61:01")
    #expect(TVDelay.seconds(Double.nan).clock() == "--:--")
    #expect(TVDelay.seconds(Double.infinity).clock() == "--:--")
}

@Test func legacyLockSerializesConcurrentUpdates() async {
    let state = TVLocked(initialState: 0)
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<100 {
            group.addTask { for _ in 0..<100 { state.withLock { $0 += 1 } } }
        }
    }
    #expect(state.withLock { $0 } == 10000)
}

@Test func legacyRegexKeepsQuotedHLSAttributesAndSubtitleMarkup() {
    #expect(HLS.attributes(#"TYPE=AUDIO,NAME="中文,声道",DEFAULT=YES"#) == ["TYPE": "AUDIO", "NAME": "中文,声道", "DEFAULT": "YES"])
    #expect(RemuxPlan.cueText(Data("<I>中文</I><font color=\"red\">🎬</font>".utf8), codec: "subrip") == "<i>中文</i>🎬")
    #expect(RemuxPlan.cueText(Data(#"0,0,Default,,0,0,0,,{\p1}m 0 0"#.utf8), codec: "ass") == nil)
}
