//
//  Statistics.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 02.10.23.
//

import Foundation

struct VideoListStatistics {
	let count: Int
	let duration: Duration
}

extension API {
	/// Only the field the statistics need, which spares decoding the full ``Video``.
	private struct VideoDuration: Decodable, Sendable {
		let duration: Int
	}

	/// Adds up a paginated video list.
	///
	/// The pages are addressed by offset, so several of them are loaded at once instead of following `next` one by one.
	/// A batch that contains a page with fewer than `pageSize` videos reached the end of the list.
	func statistics(pageSize: Int = 100, concurrentPages: Int = 5, url: (_ offset: Int, _ pageSize: Int) throws -> URL) async throws -> VideoListStatistics {
		var count = 0
		var seconds = 0
		var batchOffset = 0
		while true {
			let urls = try (0..<concurrentPages).map { index in
				try url(batchOffset + index * pageSize, pageSize)
			}
			// The requests run concurrently, the main actor is only held while building and decoding them.
			let pages = try await withThrowingTaskGroup(of: (count: Int, seconds: Int).self) { group in
				for url in urls {
					group.addTask {
						try await self.statistics(ofPageAt: url)
					}
				}
				var pages: [(count: Int, seconds: Int)] = []
				for try await page in group {
					pages.append(page)
				}
				return pages
			}
			count += pages.map(\.count).reduce(0, +)
			seconds += pages.map(\.seconds).reduce(0, +)
			if pages.contains(where: { $0.count < pageSize }) {
				return .init(count: count, duration: .seconds(seconds))
			}
			batchOffset += concurrentPages * pageSize
		}
	}

	private func statistics(ofPageAt url: URL) async throws -> (count: Int, seconds: Int) {
		let container: ListContainer<VideoDuration> = try await request(.get, url: url, authorization: .bearer)
		return (container.results.count, container.results.map(\.duration).reduce(0, +))
	}
}
