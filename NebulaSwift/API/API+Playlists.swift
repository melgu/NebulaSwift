//
//  API+Playlists.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 03.06.22.
//

import Foundation

extension API {
	private func videoContainer(for playlist: String, offset: Int, pageSize: Int) async throws -> ListContainer<Video> {
		assert(pageSize <= 100, "The Nebula API only supports page sizes up to 100")
		let url = URL(string: "https://content.watchnebula.com/engagement/playlist/list/\(playlist)/?offset=\(offset)&page_size=\(pageSize)")!
		return try await request(.get, url: url, authorization: .bearer)
	}
	
	@available(*, deprecated, message: "Use `videoContainer(for:offset:pageSize:)` instead")
	@_disfavoredOverload
	private func videoContainer(for playlist: String, page: Int, pageSize: Int) async throws -> ListContainer<Video> {
		try await videoContainer(for: playlist, offset: (page - 1) * pageSize, pageSize: pageSize)
	}
	
	private func videos(for playlist: String, page: Int, pageSize: Int = 24) async throws -> [Video] {
		let container = try await videoContainer(for: playlist, page: page, pageSize: pageSize)
		return container.results
	}
	
	private func videos(for playlist: String, count: Int) async throws -> [Video] {
		var result: [Video] = []
		var page = 1
		repeat {
			let pageSize = min(count - result.count, 100)
			let container = try await videoContainer(for: playlist, page: page, pageSize: pageSize)
			result += container.results
			guard container.next != nil else { return result }
			page += 1
		} while result.count <= count
		return result
	}
	
	private func statistics(for playlist: String) async throws -> VideoListStatistics {
		var count = 0
		var seconds = 0
		var page = 1
		while true {
			let container = try await videoContainer(for: playlist, page: page, pageSize: 100)
			count += container.results.count
			seconds += container.results.map(\.duration).reduce(0, +)
			guard container.next != nil else { break }
			page += 1
		}
		return .init(count: count, duration: .seconds(seconds))
	}
	
	private func addVideo(_ video: Video, toPlaylist playlist: String) async throws {
		let url = URL(string: "https://content.watchnebula.com/engagement/playlist/add/")!
		let body = PlaylistManagementBody(contentSlug: video.slug, playlistSlug: playlist)
		try await request(.post, url: url, body: body, authorization: .bearer)
	}
	
	private func removeVideo(_ video: Video, fromPlaylist playlist: String) async throws {
		let url = URL(string: "https://content.watchnebula.com/engagement/playlist/remove/")!
		let body = PlaylistManagementBody(contentSlug: video.slug, playlistSlug: playlist)
		try await request(.post, url: url, body: body, authorization: .bearer)
	}
	
	private struct PlaylistManagementBody: Encodable {
		let contentSlug: String
		let playlistSlug: String
	}
	
	func watchLaterVideos(page: Int, pageSize: Int = 24) async throws -> [Video] {
		try await videos(for: "watch-later", page: page, pageSize: pageSize)
	}
	
	func watchLaterVideos(count: Int) async throws -> [Video] {
		try await videos(for: "watch-later", count: count)
	}
	
	func watchLaterStatistics() async throws -> VideoListStatistics {
		try await statistics(for: "watch-later")
	}
	
	func addVideoToWatchLater(_ video: Video) async throws {
		try await addVideo(video, toPlaylist: "watch-later")
	}
	
	func removeVideoFromWatchLater(_ video: Video) async throws {
		try await removeVideo(video, fromPlaylist: "watch-later")
	}
	
	func toggleWatchLater(for video: Video) async throws {
		let watchLater: Bool
		if let engagementWatchLater = video.engagement?.watchLater {
			watchLater = engagementWatchLater
		} else {
			let video = try await self.video(for: video.slug)
			guard let engagementWatchLater = video.engagement?.watchLater else {
				throw APIError.missingEngagement
			}
			watchLater = engagementWatchLater
		}
		if watchLater {
			try await removeVideoFromWatchLater(video)
		} else {
			try await addVideoToWatchLater(video)
		}
	}
}
