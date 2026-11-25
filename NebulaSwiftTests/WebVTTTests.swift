//
//  WebVTTTests.swift
//  NebulaSwiftTests
//

import CoreMedia
import Foundation
import Testing
@testable import NebulaSwift

struct WebVTTTests {
	private func subtitles(_ texts: String...) -> WebVTT {
		var subtitles = WebVTT()
		for text in texts {
			subtitles.append(text)
		}
		return subtitles
	}
	
	// MARK: - Parsing
	
	@Test func parsesCues() {
		let subtitles = subtitles("""
			WEBVTT

			00:01.000 --> 00:02.500
			First

			intro
			01:00:03.250 --> 01:00:04.000 align:start position:10%
			Second line one
			Second line two
			""")
		
		#expect(subtitles.cues.count == 2)
		#expect(subtitles.cues[0].start == 1)
		#expect(subtitles.cues[0].end == 2.5)
		#expect(subtitles.cues[0].text == "First")
		#expect(subtitles.cues[1].start == 3603.25)
		#expect(subtitles.cues[1].end == 3604)
		#expect(subtitles.cues[1].text == "Second line one\nSecond line two")
	}
	
	@Test func handlesCRLF() {
		let subtitles = subtitles("WEBVTT\r\n\r\n00:01.000 --> 00:02.000\r\nHello\r\n")
		
		#expect(subtitles.cues.map(\.text) == ["Hello"])
	}
	
	@Test func skipsBlocksThatArentCues() {
		let subtitles = subtitles("""
			WEBVTT

			NOTE This is a comment

			STYLE
			::cue { color: yellow }

			00:05.000 --> 00:04.000
			Ends before it starts

			00:06.000 --> 00:07.000
			<i></i>

			00:08.000 --> 00:09.000
			Kept
			""")
		
		#expect(subtitles.cues.map(\.text) == ["Kept"])
	}
	
	@Test func removesMarkupAndDecodesEntities() {
		let subtitles = subtitles("""
			WEBVTT

			00:01.000 --> 00:02.000
			<v Bob><i>Hello</i></v> &lt;b&gt; &amp;lt; Tom&amp;Jerry
			""")
		
		#expect(subtitles.cues.first?.text == "Hello <b> &lt; Tom&Jerry")
	}
	
	@Test func appendsSeveralFiles() {
		let subtitles = subtitles(
			"WEBVTT\n\n00:01.000 --> 00:02.000\nOne",
			"WEBVTT\n\n00:03.000 --> 00:04.000\nTwo"
		)
		
		#expect(subtitles.cues.map(\.text) == ["One", "Two"])
	}
	
	// MARK: - 3GPP text samples
	
	private struct Sample: Equatable, CustomStringConvertible {
		let start: Double
		let end: Double
		let text: String
		
		var description: String { "\(start)–\(end): \(text.debugDescription)" }
	}
	
	/// The time and text of each sample, read back from its 16-bit length and UTF-8 bytes.
	private func samples(of subtitles: WebVTT, duration: Double) throws -> [Sample] {
		let format = try WebVTT.textFormatDescription()
		return try subtitles.textSamples(duration: duration, format: format).map { buffer in
			let bytes = try sampleBytes(buffer)
			let length = Int(bytes[0]) << 8 | Int(bytes[1])
			#expect(bytes.count == length + 2)
			let start = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
			let text = try #require(String(bytes: bytes.dropFirst(2), encoding: .utf8))
			return Sample(start: start, end: start + CMSampleBufferGetDuration(buffer).seconds, text: text)
		}
	}
	
	private func sampleBytes(_ buffer: CMSampleBuffer) throws -> [UInt8] {
		let blockBuffer = try #require(CMSampleBufferGetDataBuffer(buffer))
		var bytes = [UInt8](repeating: 0, count: CMBlockBufferGetDataLength(blockBuffer))
		let status = CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: bytes.count, destination: &bytes)
		#expect(status == noErr)
		return bytes
	}
	
	@Test func samplesCoverTheVideoWithoutOverlaps() throws {
		let subtitles = subtitles("""
			WEBVTT

			00:01.000 --> 00:03.000
			A

			00:02.000 --> 00:04.000
			B

			00:06.000 --> 00:07.000
			C

			00:09.000 --> 00:12.000
			D

			00:11.000 --> 00:12.000
			After the end
			""")
		let samples = try samples(of: subtitles, duration: 10)
		
		#expect(samples == [
			Sample(start: 0, end: 1, text: ""),
			Sample(start: 1, end: 2, text: "A"),
			Sample(start: 2, end: 3, text: "A\nB"),
			Sample(start: 3, end: 4, text: "B"),
			Sample(start: 4, end: 6, text: ""),
			Sample(start: 6, end: 7, text: "C"),
			Sample(start: 7, end: 9, text: ""),
			Sample(start: 9, end: 10, text: "D"),
		])
	}
	
	@Test func emptySubtitlesGiveOneEmptySample() throws {
		let samples = try samples(of: WebVTT(), duration: 5)
		
		#expect(samples == [Sample(start: 0, end: 5, text: "")])
	}
	
	@Test func longTextIsCutWithoutBreakingCharacters() throws {
		// Two bytes each, so the 16-bit length limit falls in the middle of one
		let text = String(repeating: "é", count: 40000)
		let subtitles = subtitles("WEBVTT\n\n00:00.000 --> 00:01.000\n\(text)")
		let samples = try samples(of: subtitles, duration: 1)
		
		#expect(samples.count == 1)
		#expect(samples.first?.text == String(repeating: "é", count: 32767))
	}
}
