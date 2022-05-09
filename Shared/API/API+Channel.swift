//
//  API+Channel.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 05.04.22.
//

import Foundation

struct ChannelEpisodesContainer: Decodable {
	let details: Channel
	let episodes: ListContainer<Video>
}

struct Channel: Decodable, Equatable {
	let slug: String
	let title: String
	let resultDescription: String?
	let assets: Assets
	let genreCategoryTitle: String
	let genreCategorySlug: String
//	let categories: [Category]
	let website: URL?
	let patreon: URL?
	let twitter: URL?
	let instagram: URL?
	let facebook: URL?
	let merch: URL?
	let merchCollection: String?
	let shareUrl: URL
	let engagement: Engagement?
//	let playlists: [Category]
	let zypeid: String?
}
extension Channel: Identifiable {
	var id: String { slug }
}

extension Channel {
	struct Assets: Decodable, Equatable {
		let avatar: [String: Avatar]
		let banner: [String: Avatar]
		let hero: [String: Avatar]?
		let featured: [String: Avatar]
	}
	
	struct Avatar: Decodable, Equatable {
		let original: URL
		let webp: URL
	}
	
	struct Engagement: Decodable, Equatable {
		let following: Bool
	}
}

extension API {
	func allChannels(page: Int, pageSize: Int = 24) async throws -> [Channel] {
		let url = URL(string: "https://content.watchnebula.com/video/channels/?page=\(page)&page_size=\(pageSize)")!
		let response: ListContainer<Channel> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	func allChannels(for category: String, page: Int, pageSize: Int = 24) async throws -> [Channel] {
		let url = URL(string: "https://content.watchnebula.com/video/channels/?category=\(category)&page=\(page)&page_size=\(pageSize)")!
		let response: ListContainer<Channel> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	func channel(for slug: String) async throws -> Channel {
		let url = URL(string: "https://content.watchnebula.com/slug/\(slug)/")!
		return try await request(.get, url: url, authorization: .bearer)
	}
	
	func channelAndVideos(for slug: String, page: Int, pageSize: Int = 24) async throws -> (Channel, [Video]) {
		let url = URL(string: "https://content.watchnebula.com/video/channels/\(slug)/?page=\(page)&page_size=\(pageSize)")!
		let container: ChannelEpisodesContainer = try await request(.get, url: url, authorization: .bearer)
		return (container.details, container.episodes.results)
	}
	
	func videos(for channel: Channel, page: Int, pageSize: Int = 24) async throws -> [Video] {
		let (_, videos) = try await channelAndVideos(for: channel.slug, page: page, pageSize: pageSize)
		return videos
	}
	
	func follow(_ channel: Channel) async throws {
		let url = URL(string: "https://content.watchnebula.com/engagement/video/follow/")!
		let body = FollowBody(channelSlug: channel.slug)
		try await request(.post, url: url, body: body, authorization: .bearer)
	}
	
	func unfollow(_ channel: Channel) async throws {
		let url = URL(string: "https://content.watchnebula.com/engagement/video/unfollow/")!
		let body = FollowBody(channelSlug: channel.slug)
		try await request(.post, url: url, body: body, authorization: .bearer)
	}
	
	private struct FollowBody: Encodable {
		let channelSlug: String
	}
}
