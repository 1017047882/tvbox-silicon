import Foundation
import Testing
@testable import TVCore

@Test func compatibleSubtitleParserReadsSRTAndWebVTTTimes() {
    let srt = "1\n01:02:03,456 --> 01:02:05,007\n字幕 🎬\n\n"
    let cues = SubtitleFile.cues(Data(srt.utf8))
    #expect(cues.count == 1)
    #expect(cues.first?.start == 3_723_456_000)
    #expect(cues.first?.end == 3_725_007_000)
    #expect(cues.first?.text == "字幕 🎬")

    let vtt = "WEBVTT\n\n00:01.5 --> 00:02.05 align:start\nHello\n\n"
    let web = SubtitleFile.cues(Data(vtt.utf8))
    #expect(web.first?.start == 1_500_000)
    #expect(web.first?.end == 2_050_000)
}

@Test func compatibleSubtitleParserReadsASSAndRejectsMissingTimes() {
    let ass = "[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\nDialogue: 0,0:00:01.25,0:00:03.50,Default,,0,0,0,,Hello\n"
    let cues = SubtitleFile.cues(Data(ass.utf8))
    #expect(cues.count == 1)
    #expect(cues.first?.start == 1_250_000)
    #expect(cues.first?.end == 3_500_000)
    #expect(cues.first?.text == "Hello")
    #expect(SubtitleFile.cues(Data("1\ninvalid --> invalid\nText\n".utf8)).isEmpty)
}

@Test func invalidSubtitleFileTimeoutReturnsWithoutFetching() async {
    let file = ExternalSubtitle(name: "Test", url: URL(string: "https://example.invalid/test.srt")!)
    let timeouts: [TimeInterval] = [0, -1, .infinity, .nan]
    for timeout in timeouts {
        #expect(await SubtitleFile.load([file], headers: [:], timeout: timeout).isEmpty)
    }
}
