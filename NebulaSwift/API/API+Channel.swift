//
//  API+Channel.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 05.04.22.
//

import Foundation
import AppIntents

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
		let avatar: [String: NebulaImageResource]
		let banner: [String: NebulaImageResource]
		let hero: [String: NebulaImageResource]?
		let featured: [String: NebulaImageResource]
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

extension API {
	func allChannels(offset: Int, pageSize: Int = 24) async throws -> [Channel] {
		let url = URL(string: "https://content.watchnebula.com/video/channels/?offset=\(offset)&page_size=\(pageSize)")!
		let response: ListContainer<Channel> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	@available(*, deprecated, message: "Use `allChannels(offset:pageSize:)` instead")
	@_disfavoredOverload
	func allChannels(page: Int, pageSize: Int = 24) async throws -> [Channel] {
		try await allChannels(offset: (page - 1) * pageSize, pageSize: pageSize)
	}
	
	func channel(for slug: Channel.ID) async throws -> Channel {
		let url = URL(string: "https://content.api.nebula.app/content/\(slug)/")!
		return try await request(.get, url: url, authorization: .bearer)
	}
	
	func channelAndVideos(for slug: Channel.ID, offset: Int, pageSize: Int = 24) async throws -> (Channel, [Video]) {
		let url = URL(string: "https://content.watchnebula.com/video/channels/\(slug)/?offset=\(offset)&page_size=\(pageSize)")!
		let response: ChannelEpisodesContainer = try await request(.get, url: url, authorization: .bearer)
		return (response.details, response.episodes.results)
	}
	
	@available(*, deprecated, message: "Use `channelAndVideos(for:offset:pageSize:)` instead")
	@_disfavoredOverload
	func channelAndVideos(for slug: Channel.ID, page: Int, pageSize: Int = 24) async throws -> (Channel, [Video]) {
		try await channelAndVideos(for: slug, offset: (page - 1) * pageSize, pageSize: pageSize)
	}
	
	private func videoContainer(for channel: Channel, offset: Int, pageSize: Int) async throws -> ListContainer<Video> {
		assert(pageSize <= 100, "The Nebula API only supports page sizes up to 100")
		let url = URL(string: "https://content.watchnebula.com/video/?channel=\(channel.slug)&offset=\(offset)&page_size=\(pageSize)")!
		return try await request(.get, url: url, authorization: .bearer)
	}
	
	@available(*, deprecated, message: "Use `videoContainer(for:offset:pageSize:)` instead")
	@_disfavoredOverload
	private func videoContainer(for channel: Channel, page: Int, pageSize: Int) async throws -> ListContainer<Video> {
		try await videoContainer(for: channel, offset: (page - 1) * pageSize, pageSize: pageSize)
	}
	
	func videos(for channel: Channel, page: Int, pageSize: Int = 24) async throws -> [Video] {
		let container = try await videoContainer(for: channel, page: page, pageSize: pageSize)
		return container.results
	}
	
	func videos(for channel: Channel, count: Int) async throws -> [Video] {
		var result: [Video] = []
		var page = 1
		repeat {
			let pageSize = min(count - result.count, 100)
			let container = try await videoContainer(for: channel, page: page, pageSize: pageSize)
			result += container.results
			guard container.next != nil else { return result }
			page += 1
		} while result.count <= count
		return result
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
		let url = URL(string: "https://content.watchnebula.com/engagement/video/follow/")!
		let body = FollowBody(channelSlug: channel.slug)
		NebulaSwiftAppShortcutsProvider.updateAppShortcutParameters()
		try await request(.post, url: url, body: body, authorization: .bearer)
	}
	
	func unfollow(_ channel: Channel) async throws {
		let url = URL(string: "https://content.watchnebula.com/engagement/video/unfollow/")!
		let body = FollowBody(channelSlug: channel.slug)
		NebulaSwiftAppShortcutsProvider.updateAppShortcutParameters()
		try await request(.post, url: url, body: body, authorization: .bearer)
	}
	
	private struct FollowBody: Encodable {
		let channelSlug: String
	}
}
