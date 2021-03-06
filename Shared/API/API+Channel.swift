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

struct Channel: Codable, Equatable, Sendable {
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
}
extension Channel: Identifiable {
	var id: String { slug }
}
extension Channel: Hashable {
	func hash(into hasher: inout Hasher) {
		hasher.combine(slug)
		hasher.combine(engagement)
	}
}

extension Channel {
	struct Assets: Codable, Equatable {
		let avatar: [String: ImageResource]
		let banner: [String: ImageResource]
		let hero: [String: ImageResource]?
		let featured: [String: ImageResource]
	}
	
	struct Engagement: Codable, Equatable, Hashable {
		let following: Bool
	}
}

extension API {
	func allChannels(page: Int, pageSize: Int = 24) async throws -> [Channel] {
		let url = URL(string: "https://content.watchnebula.com/video/channels/?page=\(page)&page_size=\(pageSize)")!
		let response: ListContainer<Channel> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	func channel(for slug: Channel.ID) async throws -> Channel {
		let url = URL(string: "https://content.watchnebula.com/slug/\(slug)/")!
		return try await request(.get, url: url, authorization: .bearer)
	}
	
	func channelAndVideos(for slug: Channel.ID, page: Int, pageSize: Int = 24) async throws -> (Channel, [Video]) {
		let url = URL(string: "https://content.watchnebula.com/video/channels/\(slug)/?page=\(page)&page_size=\(pageSize)")!
		let response: ChannelEpisodesContainer = try await request(.get, url: url, authorization: .bearer)
		return (response.details, response.episodes.results)
	}
	
	func videos(for channel: Channel, page: Int, pageSize: Int = 24) async throws -> [Video] {
		let url = URL(string: "https://content.watchnebula.com/video/?channel=\(channel.slug)&page=\(page)&page_size=\(pageSize)")!
		let response: ListContainer<Video> = try await request(.get, url: url, authorization: .bearer)
		return response.results
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
