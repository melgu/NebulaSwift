//
//  HLSPlaylist.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 05.10.26.
//

import Foundation

/// The parts of an HLS playlist needed to download a video.
enum HLSPlaylist {
	/// A multivariant playlist, listing the video's qualities and its audio and subtitle renditions.
	struct Master {
		let variants: [Variant]
		let renditions: [Rendition]
		
		init(_ text: String, baseURL: URL) throws {
			var variants: [Variant] = []
			var renditions: [Rendition] = []
			var pendingVariant: [String: String]?
			for line in text.playlistLines {
				if let attributes = line.attributes(of: "#EXT-X-STREAM-INF:") {
					pendingVariant = attributes
				} else if let attributes = line.attributes(of: "#EXT-X-MEDIA:") {
					if let rendition = Rendition(attributes, baseURL: baseURL) {
						renditions.append(rendition)
					}
				} else if !line.hasPrefix("#"), let attributes = pendingVariant {
					pendingVariant = nil
					if let variant = Variant(attributes, uri: line, baseURL: baseURL) {
						variants.append(variant)
					}
				}
			}
			guard !variants.isEmpty else { throw DownloadError.unsupportedStream }
			self.variants = variants
			self.renditions = renditions
		}
		
		/// The variant with the highest resolution up to `maxHeight`, or the smallest one if none is that small.
		///
		/// Prefers HEVC at the same resolution, since it takes up about half the space.
		func variant(maxHeight: Int?) -> Variant {
			let sorted = variants.sorted { lhs, rhs in
				(lhs.height, lhs.isHEVC ? 1 : 0, lhs.bandwidth) < (rhs.height, rhs.isHEVC ? 1 : 0, rhs.bandwidth)
			}
			guard let maxHeight else { return sorted.last! }
			return sorted.last { $0.height <= maxHeight } ?? sorted.first!
		}
		
		func renditions(_ kind: Rendition.Kind, inGroup groupID: String?) -> [Rendition] {
			guard let groupID else { return [] }
			return renditions.filter { $0.kind == kind && $0.groupID == groupID }
		}
	}
	
	struct Variant {
		/// The playlist's address as written in the multivariant playlist, which stays the same between requests.
		let path: String
		let url: URL
		let bandwidth: Int
		let height: Int
		let codecs: [String]
		let audioGroup: String?
		let subtitlesGroup: String?
		
		var isHEVC: Bool {
			codecs.contains { $0.hasPrefix("hvc1") || $0.hasPrefix("hev1") }
		}
		
		init?(_ attributes: [String: String], uri: String, baseURL: URL) {
			guard let url = URL(string: uri, relativeTo: baseURL)?.absoluteURL,
				  let bandwidth = attributes["BANDWIDTH"].flatMap(Int.init) else { return nil }
			self.path = uri
			self.url = url
			self.bandwidth = bandwidth
			self.height = attributes["RESOLUTION"]?.split(separator: "x").last.flatMap { Int($0) } ?? 0
			self.codecs = attributes["CODECS"]?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
			self.audioGroup = attributes["AUDIO"]
			self.subtitlesGroup = attributes["SUBTITLES"]
		}
	}
	
	struct Rendition {
		enum Kind: String {
			case audio = "AUDIO"
			case subtitles = "SUBTITLES"
		}
		
		let kind: Kind
		let groupID: String
		let name: String
		/// A BCP 47 language tag.
		let language: String?
		let isDefault: Bool
		/// The playlist's address as written in the multivariant playlist, which stays the same between requests.
		let path: String
		let url: URL
		
		init?(_ attributes: [String: String], baseURL: URL) {
			// Renditions without a playlist are muxed into the variant, like closed captions
			guard let kind = attributes["TYPE"].flatMap(Kind.init(rawValue:)),
				  let groupID = attributes["GROUP-ID"],
				  let uri = attributes["URI"],
				  let url = URL(string: uri, relativeTo: baseURL)?.absoluteURL else { return nil }
			self.kind = kind
			self.groupID = groupID
			self.name = attributes["NAME"] ?? ""
			self.language = attributes["LANGUAGE"]
			self.isDefault = attributes["DEFAULT"] == "YES"
			self.path = uri
			self.url = url
		}
	}
	
	/// A media playlist, listing the segments of a single rendition.
	struct Media {
		/// The fragmented MP4 header that precedes the segments.
		let initializationSegment: URL?
		let segments: [URL]
		
		init(_ text: String, baseURL: URL) throws {
			var initializationSegment: URL?
			var segments: [URL] = []
			for line in text.playlistLines {
				if let attributes = line.attributes(of: "#EXT-X-MAP:") {
					guard attributes["BYTERANGE"] == nil, let uri = attributes["URI"] else { throw DownloadError.unsupportedStream }
					initializationSegment = URL(string: uri, relativeTo: baseURL)?.absoluteURL
				} else if let attributes = line.attributes(of: "#EXT-X-KEY:") {
					guard attributes["METHOD"] == "NONE" else { throw DownloadError.unsupportedStream }
				} else if line.hasPrefix("#EXT-X-BYTERANGE") {
					throw DownloadError.unsupportedStream
				} else if !line.hasPrefix("#") {
					guard let url = URL(string: line, relativeTo: baseURL)?.absoluteURL else { throw DownloadError.unsupportedStream }
					segments.append(url)
				}
			}
			guard !segments.isEmpty else { throw DownloadError.unsupportedStream }
			self.initializationSegment = initializationSegment
			self.segments = segments
		}
	}
}

private extension String {
	var playlistLines: [String] {
		split(whereSeparator: \.isNewline)
			.map { $0.trimmingCharacters(in: .whitespaces) }
			.filter { !$0.isEmpty }
	}
	
	/// The attribute list of a tag, like `#EXT-X-MEDIA:TYPE=AUDIO,NAME="English"`, without the quotes around values.
	func attributes(of tag: String) -> [String: String]? {
		guard hasPrefix(tag) else { return nil }
		var attributes: [String: String] = [:]
		var rest = dropFirst(tag.count)[...]
		while !rest.isEmpty {
			guard let equals = rest.firstIndex(of: "=") else { break }
			let key = rest[..<equals].trimmingCharacters(in: .whitespaces)
			rest = rest[rest.index(after: equals)...]
			let value: Substring
			if rest.first == "\"" {
				// Quoted values may contain commas
				let afterQuote = rest.dropFirst()
				let closing = afterQuote.firstIndex(of: "\"") ?? afterQuote.endIndex
				value = afterQuote[..<closing]
				rest = afterQuote[closing...].drop { $0 != "," }
			} else {
				let comma = rest.firstIndex(of: ",") ?? rest.endIndex
				value = rest[..<comma]
				rest = rest[comma...]
			}
			rest = rest.drop { $0 == "," }
			attributes[key] = String(value)
		}
		return attributes
	}
}
