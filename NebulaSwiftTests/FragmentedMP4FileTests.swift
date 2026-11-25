//
//  FragmentedMP4FileTests.swift
//  NebulaSwiftTests
//

import Foundation
import Testing
@testable import NebulaSwift

struct FragmentedMP4FileTests {
	// MARK: - Building boxes
	
	private func bigEndian(_ value: UInt32) -> Data {
		withUnsafeBytes(of: value.bigEndian) { Data($0) }
	}
	
	private func box(_ type: String, _ content: Data = Data()) -> Data {
		bigEndian(UInt32(8 + content.count)) + Data(type.utf8) + content
	}
	
	/// A box with a 64-bit size, which a size of 1 announces.
	private func largeBox(_ type: String, _ content: Data) -> Data {
		bigEndian(1) + Data(type.utf8) + bigEndian(0) + bigEndian(UInt32(16 + content.count)) + content
	}
	
	/// A movie fragment header: version and flags, then the sequence number.
	private func mfhd(_ sequenceNumber: UInt32) -> Data {
		box("mfhd", Data([0, 0, 0, 0]) + bigEndian(sequenceNumber))
	}
	
	private func fragment(_ sequenceNumber: UInt32) -> Data {
		box("moof", mfhd(sequenceNumber) + box("traf", box("tfhd", Data(count: 8)))) + box("mdat", Data([1, 2, 3, 4]))
	}
	
	private var initializationSegment: Data {
		box("ftyp", Data("iso6".utf8)) + box("moov", box("mvhd", Data(count: 16)))
	}
	
	// MARK: - Reading the file back
	
	/// The sequence numbers of the movie fragments, in file order.
	private func sequenceNumbers(in data: Data) -> [UInt32] {
		var numbers: [UInt32] = []
		var offset = 0
		while offset + 8 <= data.count {
			let size = Int(uint32(in: data, at: offset))
			let type = String(decoding: data[offset + 4 ..< offset + 8], as: UTF8.self)
			if type == "moof" {
				var child = offset + 8
				while child < offset + size {
					let childSize = Int(uint32(in: data, at: child))
					if String(decoding: data[child + 4 ..< child + 8], as: UTF8.self) == "mfhd" {
						numbers.append(uint32(in: data, at: child + 12))
					}
					child += childSize
				}
			}
			offset += size
		}
		return numbers
	}
	
	private func uint32(in data: Data, at offset: Int) -> UInt32 {
		data[offset ..< offset + 4].reduce(0) { $0 << 8 | UInt32($1) }
	}
	
	private func withTemporaryURL(_ body: (URL) throws -> Void) throws {
		let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		try body(directory.appending(path: "video.mp4"))
	}
	
	// MARK: - Tests
	
	@Test func renumbersFragmentsWithoutGaps() throws {
		try withTemporaryURL { url in
			var file = try FragmentedMP4File(url: url, size: 0, fragmentCount: 0)
			try file.append(initializationSegment)
			// Each rendition only gets every few numbers, as they're counted across all of them
			try file.append(fragment(3))
			try file.append(fragment(7) + fragment(11))
			
			let data = try Data(contentsOf: url)
			#expect(sequenceNumbers(in: data) == [1, 2, 3])
			#expect(file.fragmentCount == 3)
			#expect(file.size == UInt64(data.count))
			#expect(data.count == initializationSegment.count + 3 * fragment(1).count)
		}
	}
	
	@Test func leavesInitializationSegmentUnchanged() throws {
		try withTemporaryURL { url in
			var file = try FragmentedMP4File(url: url, size: 0, fragmentCount: 0)
			try file.append(initializationSegment)
			
			#expect(try Data(contentsOf: url) == initializationSegment)
			#expect(file.fragmentCount == 0)
		}
	}
	
	@Test func continuesAfterWhatWasWritten() throws {
		try withTemporaryURL { url in
			var file = try FragmentedMP4File(url: url, size: 0, fragmentCount: 0)
			try file.append(fragment(4))
			let sizeAfterFirst = file.size
			// Written, but not recorded before the download stopped
			try file.append(fragment(8))
			
			var resumed = try FragmentedMP4File(url: url, size: sizeAfterFirst, fragmentCount: 1)
			#expect(try Data(contentsOf: url).count == Int(sizeAfterFirst))
			try resumed.append(fragment(12))
			
			#expect(sequenceNumbers(in: try Data(contentsOf: url)) == [1, 2])
			#expect(resumed.fragmentCount == 2)
		}
	}
	
	@Test func handlesLargeSizeAndOpenEndedBoxes() throws {
		try withTemporaryURL { url in
			var file = try FragmentedMP4File(url: url, size: 0, fragmentCount: 0)
			// A size of 0 makes the box reach to the end of the data
			let openEndedMdat = bigEndian(0) + Data("mdat".utf8) + Data([9, 9, 9])
			try file.append(largeBox("moof", mfhd(5)) + openEndedMdat)
			
			let data = try Data(contentsOf: url)
			#expect(file.fragmentCount == 1)
			#expect(uint32(in: data, at: 16 + 12) == 1)
		}
	}
	
	@Test(arguments: [
		// Claims more bytes than there are
		Data([0, 0, 0, 100]) + Data("moof".utf8) + Data(count: 8),
		// Shorter than its own header
		Data([0, 0, 0, 4]) + Data("moof".utf8),
		// Cut off within the header
		Data([0, 0, 0]),
	])
	func malformedBoxesFail(segment: Data) throws {
		try withTemporaryURL { url in
			var file = try FragmentedMP4File(url: url, size: 0, fragmentCount: 0)
			expectUnsupportedStream {
				try file.append(segment)
			}
		}
	}
	
	@Test func truncatedFragmentHeaderFails() throws {
		try withTemporaryURL { url in
			var file = try FragmentedMP4File(url: url, size: 0, fragmentCount: 0)
			let shortMfhd = box("mfhd", Data([0, 0, 0, 0]))
			expectUnsupportedStream {
				try file.append(box("moof", shortMfhd))
			}
		}
	}
}
