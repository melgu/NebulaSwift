//
//  API+Channel.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 05.04.22.
//

import Foundation
import AppIntents

struct Channel: Codable, Equatable, Sendable {
	/// The API's own identifier, e.g. `video_channel:<uuid>`. Engagement is keyed by it.
	let channelId: String
	let slug: String
	let title: String
	let description: String?
	let images: Images
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
	var engagement: Engagement?
//	let playlists: [Category]
	
	enum CodingKeys: String, CodingKey {
		case channelId = "id"
		case slug
		case title
		case description
		case images
		case genreCategoryTitle
		case genreCategorySlug
		case website
		case patreon
		case twitter
		case instagram
		case facebook
		case merch
		case merchCollection
		case shareUrl
		case engagement
	}
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
	struct Images: Codable, Equatable {
		let avatar: NebulaImage
		let banner: NebulaImage?
		let hero: NebulaImage?
		let featured: NebulaImage
		
		/// The widest image available. The trimmed channels in featured rails have no banner.
		var wide: NebulaImage { banner ?? featured }
	}
	
	struct Engagement: Codable, Equatable, Hashable {
		let following: Bool
	}
}

extension Channel: AppEntity {
	static let defaultQuery: ChannelQuery = .init()
	
	static let typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: "Channel")
	
	var displayRepresentation: DisplayRepresentation {
		.init(stringLiteral: title)
	}
}

/// The engagement endpoints only return the content's identifier, not its slug.
private struct ChannelEngagement: Decodable {
	let id: String
	let following: Bool
}

extension API {
	func allChannels(offset: Int, pageSize: Int = 24) async throws -> [Channel] {
		let url = try URL(string: "https://content.api.nebula.app/video_channels/?ordering=title&offset=\(offset)&page_size=\(pageSize)").require()
		let response: ListContainer<Channel> = try await request(.get, url: url, authorization: .bearer)
		return try await withEngagement(response.results)
	}
	
	@available(*, deprecated, message: "Use `allChannels(offset:pageSize:)` instead")
	@_disfavoredOverload
	func allChannels(page: Int, pageSize: Int = 24) async throws -> [Channel] {
		try await allChannels(offset: (page - 1) * pageSize, pageSize: pageSize)
	}
	
	func channel(for slug: Channel.ID) async throws -> Channel {
		let url = try URL(string: "https://content.api.nebula.app/video_channels/\(slug)/").require()
		return try await request(.get, url: url, authorization: .bearer)
	}
	
	/// The channel endpoints no longer embed engagement, so it has to be fetched separately.
	func withEngagement(_ channels: [Channel]) async throws -> [Channel] {
		var engagements: [String: Channel.Engagement] = [:]
		for chunk in channels.chunked(into: 100) {
			let ids = chunk.map(\.channelId).joined(separator: ",")
			let url = try URL(string: "https://content.api.nebula.app/video_channels/engagement/?ids=\(ids)&page_size=\(chunk.count)").require()
			let response: ListContainer<ChannelEngagement> = try await request(.get, url: url, authorization: .bearer)
			for engagement in response.results {
				engagements[engagement.id] = .init(following: engagement.following)
			}
		}
		return channels.map { channel in
			var channel = channel
			channel.engagement = engagements[channel.channelId] ?? channel.engagement
			return channel
		}
	}
	
	func isFollowing(_ channel: Channel) async throws -> Bool {
		try await withEngagement([channel]).first?.engagement?.following ?? false
	}
	
	private func videoContainer(for channel: Channel, offset: Int, pageSize: Int) async throws -> ListContainer<Video> {
		assert(pageSize <= 100, "The Nebula API only supports page sizes up to 100")
		let url = try URL(string: "https://content.api.nebula.app/video_channels/\(channel.slug)/video_episodes/?offset=\(offset)&page_size=\(pageSize)").require()
		return try await request(.get, url: url, authorization: .bearer)
	}
	
	@available(*, deprecated, message: "Use `videoContainer(for:offset:pageSize:)` instead")
	@_disfavoredOverload
	private func videoContainer(for channel: Channel, page: Int, pageSize: Int) async throws -> ListContainer<Video> {
		try await videoContainer(for: channel, offset: (page - 1) * pageSize, pageSize: pageSize)
	}
	
	func videos(for channel: Channel, page: Int, pageSize: Int = 24) async throws -> [Video] {
		let container = try await videoContainer(for: channel, page: page, pageSize: pageSize)
		return try await withEngagement(container.results)
	}
	
	func videos(for channel: Channel, count: Int) async throws -> [Video] {
		var result: [Video] = []
		var page = 1
		repeat {
			let pageSize = min(count - result.count, 100)
			let container = try await videoContainer(for: channel, page: page, pageSize: pageSize)
			result += container.results
			guard container.next != nil else { return try await withEngagement(result) }
			page += 1
		} while result.count <= count
		return try await withEngagement(result)
	}
	
	func statistics(for channel: Channel) async throws -> VideoListStatistics {
		var count = 0
		var seconds = 0
		var page = 1
		while true {
			let container = try await videoContainer(for: channel, page: page, pageSize: 100)
			count += container.results.count
			seconds += container.results.map(\.duration).reduce(0, +)
			guard container.next != nil else { break }
			page += 1
		}
		return .init(count: count, duration: .seconds(seconds))
	}
	
	func follow(_ channel: Channel) async throws {
		let url = try URL(string: "https://content.api.nebula.app/engagement/video/follow/").require()
		let body = FollowBody(channelSlug: channel.slug)
		NebulaSwiftAppShortcutsProvider.updateAppShortcutParameters()
		try await request(.post, url: url, body: body, authorization: .bearer)
	}
	
	func unfollow(_ channel: Channel) async throws {
		let url = try URL(string: "https://content.api.nebula.app/engagement/video/unfollow/").require()
		let body = FollowBody(channelSlug: channel.slug)
		NebulaSwiftAppShortcutsProvider.updateAppShortcutParameters()
		try await request(.post, url: url, body: body, authorization: .bearer)
	}
	
	private struct FollowBody: Encodable {
		let channelSlug: String
	}
}
