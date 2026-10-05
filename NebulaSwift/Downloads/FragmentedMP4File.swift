//
//  FragmentedMP4File.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 05.10.26.
//

import Foundation

/// A fragmented MP4 file built from an HLS rendition's segments, one after the other.
///
/// The segments are numbered as part of all renditions, so a single rendition skips numbers.
/// AVFoundation stops reading at the first gap, so every movie fragment gets renumbered on the way in.
struct FragmentedMP4File {
	let url: URL
	/// How many movie fragments the file holds, which is also the number of the last one.
	private(set) var fragmentCount: UInt32
	private(set) var size: UInt64
	
	/// Opens the file to continue where it was left, dropping anything written after that.
	init(url: URL, size: UInt64, fragmentCount: UInt32) throws {
		self.url = url
		self.size = size
		self.fragmentCount = fragmentCount
		if !FileManager.default.fileExists(atPath: url.path) {
			FileManager.default.createFile(atPath: url.path, contents: nil)
		}
		let handle = try FileHandle(forWritingTo: url)
		defer { try? handle.close() }
		try handle.truncate(atOffset: size)
	}
	
	mutating func append(_ segment: Data) throws {
		var segment = segment
		try renumberFragments(in: &segment)
		let handle = try FileHandle(forWritingTo: url)
		defer { try? handle.close() }
		try handle.seek(toOffset: size)
		try handle.write(contentsOf: segment)
		size += UInt64(segment.count)
	}
	
	private mutating func renumberFragments(in data: inout Data) throws {
		var offset = data.startIndex
		while offset < data.endIndex {
			let box = try Box(in: data, at: offset)
			if box.type == "moof" {
				var child = box.contentStart
				while child < box.end {
					let childBox = try Box(in: data, at: child)
					if childBox.type == "mfhd" {
						fragmentCount += 1
						// Full box: version and flags, then the sequence number
						let sequenceNumberOffset = childBox.contentStart + 4
						guard sequenceNumberOffset + 4 <= childBox.end else { throw DownloadError.unsupportedStream }
						withUnsafeBytes(of: fragmentCount.bigEndian) { bytes in
							data.replaceSubrange(sequenceNumberOffset ..< sequenceNumberOffset + 4, with: bytes)
						}
					}
					child = childBox.end
				}
			}
			offset = box.end
		}
	}
}

/// The header of an ISO base media file box.
private struct Box {
	let type: String
	let contentStart: Int
	let end: Int
	
	init(in data: Data, at offset: Int) throws {
		guard offset + 8 <= data.endIndex else { throw DownloadError.unsupportedStream }
		var size = UInt64(data.bigEndianUInt32(at: offset))
		type = String(decoding: data[offset + 4 ..< offset + 8], as: UTF8.self)
		var headerSize = 8
		if size == 1 {
			guard offset + 16 <= data.endIndex else { throw DownloadError.unsupportedStream }
			size = UInt64(data.bigEndianUInt32(at: offset + 8)) << 32 | UInt64(data.bigEndianUInt32(at: offset + 12))
			headerSize = 16
		} else if size == 0 {
			// Extends to the end of the data
			size = UInt64(data.endIndex - offset)
		}
		guard size >= UInt64(headerSize), UInt64(offset) + size <= UInt64(data.endIndex) else { throw DownloadError.unsupportedStream }
		contentStart = offset + headerSize
		end = offset + Int(size)
	}
}

private extension Data {
	func bigEndianUInt32(at offset: Int) -> UInt32 {
		self[offset ..< offset + 4].reduce(0) { $0 << 8 | UInt32($1) }
	}
}
