//
//  HLSPlaylistTests.swift
//  NebulaSwiftTests
//

import Foundation
import Testing
@testable import NebulaSwift

struct HLSPlaylistTests {
	let baseURL = URL(string: "https://cdn.example.com/stream/master.m3u8?signature=abc")!
	
	// MARK: - Master
	
	@Test func masterParsesVariants() throws {
		let text = """
			#EXTM3U
			#EXT-X-STREAM-INF:BANDWIDTH=1500000,RESOLUTION=1280x720,CODECS="avc1.64001f,mp4a.40.2",AUDIO="aac",SUBTITLES="subs"
			720/index.m3u8
			#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,CODECS="hvc1.2.4.L123.B0, mp4a.40.2",AUDIO="aac"
			https://other.example.com/1080/index.m3u8
			"""
		let master = try HLSPlaylist.Master(text, baseURL: baseURL)
		
		#expect(master.variants.count == 2)
		let first = master.variants[0]
		#expect(first.path == "720/index.m3u8")
		#expect(first.url.absoluteString == "https://cdn.example.com/stream/720/index.m3u8")
		#expect(first.bandwidth == 1500000)
		#expect(first.height == 720)
		#expect(first.codecs == ["avc1.64001f", "mp4a.40.2"])
		#expect(first.audioGroup == "aac")
		#expect(first.subtitlesGroup == "subs")
		#expect(!first.isHEVC)
		
		let second = master.variants[1]
		#expect(second.url.absoluteString == "https://other.example.com/1080/index.m3u8")
		#expect(second.codecs == ["hvc1.2.4.L123.B0", "mp4a.40.2"])
		#expect(second.subtitlesGroup == nil)
		#expect(second.isHEVC)
	}
	
	@Test func masterParsesRenditions() throws {
		let text = """
			#EXTM3U
			#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",NAME="English",LANGUAGE="en",DEFAULT=YES,URI="audio/en.m3u8"
			#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",NAME="Deutsch, Synchronfassung",LANGUAGE="de",DEFAULT=NO,URI="audio/de.m3u8"
			#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="other",NAME="Commentary",URI="audio/commentary.m3u8"
			#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",URI="subs/en.m3u8"
			#EXT-X-STREAM-INF:BANDWIDTH=1500000,RESOLUTION=1280x720,AUDIO="aac",SUBTITLES="subs"
			720/index.m3u8
			"""
		let master = try HLSPlaylist.Master(text, baseURL: baseURL)
		let variant = try #require(master.variants.first)
		
		let audio = master.renditions(.audio, inGroup: variant.audioGroup)
		#expect(audio.map(\.name) == ["English", "Deutsch, Synchronfassung"])
		#expect(audio.map(\.language) == ["en", "de"])
		#expect(audio.map(\.isDefault) == [true, false])
		#expect(audio[0].path == "audio/en.m3u8")
		#expect(audio[0].url.absoluteString == "https://cdn.example.com/stream/audio/en.m3u8")
		
		let subtitles = master.renditions(.subtitles, inGroup: variant.subtitlesGroup)
		#expect(subtitles.map(\.url.lastPathComponent) == ["en.m3u8"])
		#expect(subtitles.first?.kind == .subtitles)
		
		#expect(master.renditions(.subtitles, inGroup: nil).isEmpty)
	}
	
	@Test func masterSkipsRenditionsWithoutPlaylist() throws {
		let text = """
			#EXTM3U
			#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",NAME="Muxed"
			#EXT-X-MEDIA:TYPE=CLOSED-CAPTIONS,GROUP-ID="cc",NAME="CC",INSTREAM-ID="CC1"
			#EXT-X-STREAM-INF:BANDWIDTH=1500000,AUDIO="aac",CLOSED-CAPTIONS="cc"
			index.m3u8
			"""
		let master = try HLSPlaylist.Master(text, baseURL: baseURL)
		
		#expect(master.renditions.isEmpty)
	}
	
	@Test func masterSkipsVariantsWithoutBandwidth() throws {
		let text = """
			#EXTM3U
			#EXT-X-STREAM-INF:RESOLUTION=1920x1080
			no-bandwidth.m3u8
			#EXT-X-STREAM-INF:BANDWIDTH=100
			no-resolution.m3u8
			"""
		let master = try HLSPlaylist.Master(text, baseURL: baseURL)
		
		#expect(master.variants.map(\.path) == ["no-resolution.m3u8"])
		#expect(master.variants.first?.height == 0)
	}
	
	@Test func masterHandlesCRLFAndBlankLines() throws {
		let text = "#EXTM3U\r\n\r\n#EXT-X-STREAM-INF:BANDWIDTH=100,RESOLUTION=640x360\r\n  360.m3u8  \r\n"
		let master = try HLSPlaylist.Master(text, baseURL: baseURL)
		
		#expect(master.variants.map(\.path) == ["360.m3u8"])
		#expect(master.variants.first?.height == 360)
	}
	
	@Test func masterKeepsUnterminatedQuotedValue() throws {
		let text = """
			#EXTM3U
			#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",URI="audio.m3u8",NAME="Broken
			#EXT-X-STREAM-INF:BANDWIDTH=100
			index.m3u8
			"""
		let master = try HLSPlaylist.Master(text, baseURL: baseURL)
		
		#expect(master.renditions.map(\.name) == ["Broken"])
	}
	
	@Test func masterWithoutVariantsFails() {
		let text = """
			#EXTM3U
			#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",NAME="English",URI="audio.m3u8"
			"""
		expectUnsupportedStream {
			_ = try HLSPlaylist.Master(text, baseURL: baseURL)
		}
	}
	
	// MARK: - Variant selection
	
	private var qualities: HLSPlaylist.Master {
		get throws {
			let text = """
				#EXTM3U
				#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360,CODECS="avc1.4d401e"
				360.m3u8
				#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720,CODECS="avc1.64001f"
				720-avc.m3u8
				#EXT-X-STREAM-INF:BANDWIDTH=1200000,RESOLUTION=1280x720,CODECS="hvc1.1.6.L93.B0"
				720-hevc.m3u8
				#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,CODECS="avc1.640028"
				1080.m3u8
				"""
			return try HLSPlaylist.Master(text, baseURL: baseURL)
		}
	}
	
	@Test func variantWithoutLimitIsTheHighest() throws {
		#expect(try qualities.variant(maxHeight: nil).path == "1080.m3u8")
	}
	
	@Test(arguments: [720, 1000])
	func variantPrefersHEVCAtTheSameHeight(maxHeight: Int) throws {
		#expect(try qualities.variant(maxHeight: maxHeight).path == "720-hevc.m3u8")
	}
	
	@Test func variantBelowAllHeightsIsTheSmallest() throws {
		#expect(try qualities.variant(maxHeight: 240).path == "360.m3u8")
	}
	
	// MARK: - Media
	
	@Test func mediaParsesSegments() throws {
		let text = """
			#EXTM3U
			#EXT-X-VERSION:7
			#EXT-X-TARGETDURATION:6
			#EXT-X-KEY:METHOD=NONE
			#EXT-X-MAP:URI="init.mp4"
			#EXTINF:6.0,
			segment-1.m4s
			#EXTINF:6.0,
			https://other.example.com/segment-2.m4s
			#EXT-X-ENDLIST
			"""
		let media = try HLSPlaylist.Media(text, baseURL: baseURL)
		
		#expect(media.initializationSegment?.absoluteString == "https://cdn.example.com/stream/init.mp4")
		#expect(media.segments.map(\.absoluteString) == [
			"https://cdn.example.com/stream/segment-1.m4s",
			"https://other.example.com/segment-2.m4s",
		])
	}
	
	@Test func mediaWithoutMapHasNoInitializationSegment() throws {
		let text = """
			#EXTM3U
			#EXTINF:60.0,
			subtitles-1.vtt
			"""
		let media = try HLSPlaylist.Media(text, baseURL: baseURL)
		
		#expect(media.initializationSegment == nil)
		#expect(media.segments.count == 1)
	}
	
	@Test(arguments: [
		"#EXT-X-MAP:URI=\"init.mp4\",BYTERANGE=\"720@0\"\n#EXTINF:6.0,\nsegment.m4s",
		"#EXT-X-KEY:METHOD=AES-128,URI=\"key\"\n#EXTINF:6.0,\nsegment.m4s",
		"#EXTINF:6.0,\n#EXT-X-BYTERANGE:1000@0\nsegment.m4s",
		"#EXT-X-TARGETDURATION:6\n#EXT-X-ENDLIST",
	])
	func mediaWithUnsupportedFeaturesFails(body: String) {
		expectUnsupportedStream {
			_ = try HLSPlaylist.Media("#EXTM3U\n" + body, baseURL: baseURL)
		}
	}
}

/// Expects the code to fail because the downloader can't handle the stream.
func expectUnsupportedStream(sourceLocation: SourceLocation = #_sourceLocation, _ body: () throws -> Void) {
	let error = #expect(throws: DownloadError.self, sourceLocation: sourceLocation, performing: body)
	guard let error else { return }
	guard case .unsupportedStream = error else {
		Issue.record("Expected unsupportedStream, got \(error)", sourceLocation: sourceLocation)
		return
	}
}
