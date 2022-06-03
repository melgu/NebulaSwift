//
//  API+Playlists.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 03.06.22.
//

import Foundation

extension API {
	private func videos(for playlist: String, page: Int, pageSize: Int = 24) async throws -> [Video] {
		let url = URL(string: "https://content.watchnebula.com/engagement/playlist/list/\(playlist)/?&page=\(page)&page_size=\(pageSize)")!
		let response: ListContainer<Video> = try await request(.get, url: url, authorization: .bearer)
		return response.results
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
	
	func addVideoToWatchLater(_ video: Video) async throws {
		try await addVideo(video, toPlaylist: "watch-later")
	}
	
	func removeVideoFromWatchLater(_ video: Video) async throws {
		try await removeVideo(video, fromPlaylist: "watch-later")
	}
}
