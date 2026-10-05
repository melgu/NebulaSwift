//
//  WebVTT.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 05.10.26.
//

import CoreMedia
import Foundation

/// Subtitles from WebVTT files, which MP4 can't hold, turned into a 3GPP text track, which it can.
struct WebVTT {
	struct Cue {
		let start: Double
		let end: Double
		let text: String
	}
	
	private(set) var cues: [Cue] = []
	
	/// Adds the cues of a WebVTT file. Subtitle playlists may split them over several files.
	mutating func append(_ text: String) {
		let blocks = text
			.replacingOccurrences(of: "\r\n", with: "\n")
			.components(separatedBy: "\n\n")
		for block in blocks {
			let lines = block.split(separator: "\n").map(String.init)
			// The timing line may follow an identifier
			guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
			let timing = lines[timingIndex].components(separatedBy: "-->")
			guard timing.count == 2,
				  let start = Self.seconds(timing[0]),
				  let end = Self.seconds(timing[1]),
				  end > start else { continue }
			let text = Self.plainText(lines[(timingIndex + 1)...].joined(separator: "\n"))
			guard !text.isEmpty else { continue }
			cues.append(Cue(start: start, end: end, text: text))
		}
	}
	
	/// Parses `hh:mm:ss.ttt` or `mm:ss.ttt`, ignoring cue settings after it.
	private static func seconds(_ timestamp: String) -> Double? {
		guard let token = timestamp.split(separator: " ", omittingEmptySubsequences: true).first else { return nil }
		var seconds = 0.0
		for component in token.split(separator: ":") {
			guard let value = Double(component) else { return nil }
			seconds = seconds * 60 + value
		}
		return seconds
	}
	
	/// Removes markup like `<i>` or `<v Speaker>`, which 3GPP text can't show.
	private static func plainText(_ text: String) -> String {
		text
			.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
			.replacingOccurrences(of: "&lt;", with: "<")
			.replacingOccurrences(of: "&gt;", with: ">")
			.replacingOccurrences(of: "&nbsp;", with: "\u{00A0}")
			.replacingOccurrences(of: "&lrm;", with: "\u{200E}")
			.replacingOccurrences(of: "&rlm;", with: "\u{200F}")
			.replacingOccurrences(of: "&amp;", with: "&")
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}

// MARK: - 3GPP Text

extension WebVTT {
	/// White text at the bottom center, like the player shows WebVTT by default.
	static func textFormatDescription() throws -> CMFormatDescription {
		func color(_ value: Int, alpha: Int = 255) -> [CFString: Int] {
			[
				kCMTextFormatDescriptionColor_Red: value,
				kCMTextFormatDescriptionColor_Green: value,
				kCMTextFormatDescriptionColor_Blue: value,
				kCMTextFormatDescriptionColor_Alpha: alpha,
			]
		}
		let extensions: [CFString: Any] = [
			kCMTextFormatDescriptionExtension_DisplayFlags: 0,
			kCMTextFormatDescriptionExtension_BackgroundColor: color(0, alpha: 0),
			kCMTextFormatDescriptionExtension_DefaultTextBox: [
				kCMTextFormatDescriptionRect_Top: 0,
				kCMTextFormatDescriptionRect_Left: 0,
				kCMTextFormatDescriptionRect_Bottom: 0,
				kCMTextFormatDescriptionRect_Right: 0,
			],
			kCMTextFormatDescriptionExtension_DefaultStyle: [
				kCMTextFormatDescriptionStyle_StartChar: 0,
				kCMTextFormatDescriptionStyle_EndChar: 0,
				kCMTextFormatDescriptionStyle_Font: 1,
				kCMTextFormatDescriptionStyle_FontFace: 0,
				kCMTextFormatDescriptionStyle_ForegroundColor: color(255),
				kCMTextFormatDescriptionStyle_FontSize: 18,
			] as [CFString: Any],
			kCMTextFormatDescriptionExtension_HorizontalJustification: 1,
			kCMTextFormatDescriptionExtension_VerticalJustification: -1,
			kCMTextFormatDescriptionExtension_FontTable: ["1": "Sans-Serif"],
		]
		var description: CMFormatDescription?
		let status = CMFormatDescriptionCreate(
			allocator: kCFAllocatorDefault,
			mediaType: kCMMediaType_Subtitle,
			mediaSubType: kCMTextFormatType_3GText,
			extensions: extensions as CFDictionary,
			formatDescriptionOut: &description
		)
		guard status == noErr, let description else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
		return description
	}
	
	/// Samples covering the whole video without overlaps, as 3GPP text requires.
	///
	/// Gaps between cues become empty samples, and cues showing at the same time are joined.
	func textSamples(duration: Double, format: CMFormatDescription) throws -> [CMSampleBuffer] {
		var boundaries: Set<Double> = [0, duration]
		for cue in cues where cue.start < duration {
			boundaries.insert(cue.start)
			boundaries.insert(min(cue.end, duration))
		}
		let sorted = boundaries.sorted()
		return try zip(sorted, sorted.dropFirst()).map { start, end in
			let text = cues
				.filter { $0.start <= start && $0.end >= end }
				.map(\.text)
				.joined(separator: "\n")
			return try Self.textSample(text, start: start, end: end, format: format)
		}
	}
	
	/// A sample holding the text's length as a 16-bit big-endian integer, followed by the text in UTF-8.
	private static func textSample(_ text: String, start: Double, end: Double, format: CMFormatDescription) throws -> CMSampleBuffer {
		var utf8 = Array(text.utf8.prefix(Int(UInt16.max)))
		// Don't cut a character in half
		while !utf8.isEmpty, String(bytes: utf8, encoding: .utf8) == nil {
			utf8.removeLast()
		}
		var bytes = withUnsafeBytes(of: UInt16(utf8.count).bigEndian, Array.init) + utf8
		
		var blockBuffer: CMBlockBuffer?
		var status = CMBlockBufferCreateWithMemoryBlock(
			allocator: kCFAllocatorDefault,
			memoryBlock: nil,
			blockLength: bytes.count,
			blockAllocator: kCFAllocatorDefault,
			customBlockSource: nil,
			offsetToData: 0,
			dataLength: bytes.count,
			flags: kCMBlockBufferAssureMemoryNowFlag,
			blockBufferOut: &blockBuffer
		)
		guard status == noErr, let blockBuffer else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
		status = CMBlockBufferReplaceDataBytes(with: &bytes, blockBuffer: blockBuffer, offsetIntoDestination: 0, dataLength: bytes.count)
		guard status == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
		
		let timescale: CMTimeScale = 1000
		var timing = CMSampleTimingInfo(
			duration: CMTime(seconds: end - start, preferredTimescale: timescale),
			presentationTimeStamp: CMTime(seconds: start, preferredTimescale: timescale),
			decodeTimeStamp: .invalid
		)
		var size = bytes.count
		var sampleBuffer: CMSampleBuffer?
		status = CMSampleBufferCreate(
			allocator: kCFAllocatorDefault,
			dataBuffer: blockBuffer,
			dataReady: true,
			makeDataReadyCallback: nil,
			refcon: nil,
			formatDescription: format,
			sampleCount: 1,
			sampleTimingEntryCount: 1,
			sampleTimingArray: &timing,
			sampleSizeEntryCount: 1,
			sampleSizeArray: &size,
			sampleBufferOut: &sampleBuffer
		)
		guard status == noErr, let sampleBuffer else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
		return sampleBuffer
	}
}
