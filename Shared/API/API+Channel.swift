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

struct Channel: Decodable {
	let slug: String
	let title: String
	let resultDescription: String?
	let assets: ChannelAssets
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
	let shareurl: URL?
	let engagement: ChannelEngagement
//	let playlists: [Category]
	let zypeid: String?
}
extension Channel: Identifiable {
	var id: String { slug }
}

struct ChannelAssets: Decodable {
	let avatar: [String: ChannelAvatar]
	let banner: [String: ChannelAvatar]
	let hero: [String: ChannelAvatar]?
	let featured: [String: ChannelAvatar]
}

struct ChannelEngagement: Decodable {
	let following: Bool
}

extension API {
	func channel(for slug: String) async throws -> Channel {
		let url = URL(string: "https://content.watchnebula.com/slug/\(slug)/")!
		return try await request(.get, url: url, authorization: .bearer)
	}
	
	func channelAndVideos(for slug: String, page: Int, pageSize: Int = 20) async throws -> (Channel, [Video]) {
		let url = URL(string: "https://content.watchnebula.com/video/channels/\(slug)/?page=\(page)&pageSize=\(pageSize)")!
		let container: ChannelEpisodesContainer = try await request(.get, url: url, authorization: .bearer)
		return (container.details, container.episodes.results)
	}
	
	func videos(for channel: Channel, page: Int, pageSize: Int = 20) async throws -> [Video] {
		let (_, videos) = try await channelAndVideos(for: channel.slug, page: page, pageSize: pageSize)
		return videos
	}
}
