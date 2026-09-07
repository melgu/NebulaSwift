//
//  API+Video.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 17.11.21.
//

import Foundation

// MARK: Info

struct Video: Codable, Equatable, Sendable {
	/// The API's own identifier, e.g. `video_episode:<uuid>`. Engagement is keyed by it.
	let episodeId: String
	let slug: String
	let title: String
	let description: String
	let shortDescription: String
	let duration: Int
	let publishedAt: Date
	let channelSlug: String
	let channelSlugs: [String]?
	let channelTitle: String
	/// Full episodes come with `category_slugs`, the trimmed ones in featured rails with `categories`.
	private let ownCategorySlugs: [String]?
	private let categories: [String]?
	let images: Images
	let attributes: [Attribute]
	let shareUrl: URL
//	let channel: NSNull
	var engagement: Engagement?
	
	enum CodingKeys: String, CodingKey {
		case episodeId = "id"
		case slug
		case title
		case description
		case shortDescription
		case duration
		case publishedAt
		case channelSlug
		case channelSlugs
		case channelTitle
		case ownCategorySlugs = "categorySlugs"
		case categories
		case images
		case attributes
		case shareUrl
		case engagement
	}
}
extension Video {
	var categorySlugs: [String] { ownCategorySlugs ?? categories ?? [] }
}
extension Video: Identifiable {
	var id: String { slug + "\(engagement?.progress ?? 0)" }
}
extension Video: Hashable {
	func hash(into hasher: inout Hasher) {
		hasher.combine(slug)
		hasher.combine(engagement)
	}
}

extension Video {
	struct Images: Codable, Equatable {
		let channelAvatar: NebulaImage
		let thumbnail: NebulaImage
	}
	
	enum Attribute: String, Codable, Equatable {
		case freeSampleEligible = "free_sample_eligible"
		case isNebulaPlus = "is_nebula_plus"
		case isNebulaOriginal = "is_nebula_original"
		case isNebulaFirst = "is_nebula_first"
	}
	
	struct Engagement: Codable, Equatable, Hashable {
		let contentSlug: String
		let updatedAt: Date?
		let progress: Int
		let completed: Bool
		let watchLater: Bool
	}
}

/// The engagement endpoints only return the content's identifier, not its slug.
private struct EpisodeEngagement: Decodable {
	let id: String
	let watchLater: Bool
	let progress: Progress?
	
	struct Progress: Decodable {
		let value: Int
		let completed: Bool
		let updatedAt: Date
	}
	
	func engagement(forSlug slug: String) -> Video.Engagement {
		.init(
			contentSlug: slug,
			updatedAt: progress?.updatedAt,
			progress: progress?.value ?? 0,
			completed: progress?.completed ?? false,
			watchLater: watchLater
		)
	}
}

struct Progress: Encodable {
	let contentSlug: String
	let value: Int
}

struct Completed: Encodable {
	let contentSlug: String
	let completed = true
}

extension API {
	func allVideos(offset: Int, pageSize: Int = 24) async throws -> [Video] {
		let url = try URL(string: "https://content.api.nebula.app/video_episodes/?offset=\(offset)&page_size=\(pageSize)").require()
		let response: ListContainer<Video> = try await request(.get, url: url, authorization: .bearer)
		return try await withEngagement(response.results)
	}
	
	@available(*, deprecated, message: "Use `allVideos(offset:pageSize:)` instead")
	@_disfavoredOverload
	func allVideos(page: Int, pageSize: Int = 24) async throws -> [Video] {
		try await allVideos(offset: (page - 1) * pageSize, pageSize: pageSize)
	}
	
	func video(for slug: String) async throws -> Video {
		let url = try URL(string: "https://content.api.nebula.app/video_episodes/\(slug)/").require()
		let video: Video = try await request(.get, url: url, authorization: .bearer)
		return try await withEngagement([video]).first ?? video
	}
	
	/// The video endpoints no longer embed engagement, so it has to be fetched separately.
	func withEngagement(_ videos: [Video]) async throws -> [Video] {
		var engagements: [String: EpisodeEngagement] = [:]
		for chunk in videos.chunked(into: 100) {
			let ids = chunk.map(\.episodeId).joined(separator: ",")
			let url = try URL(string: "https://content.api.nebula.app/video_episodes/engagement/?ids=\(ids)&page_size=\(chunk.count)").require()
			let response: ListContainer<EpisodeEngagement> = try await request(.get, url: url, authorization: .bearer)
			for engagement in response.results {
				engagements[engagement.id] = engagement
			}
		}
		return videos.map { video in
			var video = video
			video.engagement = engagements[video.episodeId]?.engagement(forSlug: video.slug) ?? video.engagement
			return video
		}
	}
	
	/// The URL of the video's HLS master playlist.
	///
	/// The endpoint redirects to a signed playlist on Nebula's CDN, so the URL can be handed to a
	/// player as is. Subtitles and thumbnails are part of the playlist. Only the episode's
	/// identifier is accepted, not its slug.
	func manifestURL(for video: Video) throws -> URL {
		guard let bearer else { throw APIError.missingBearer }
		var components = try URLComponents(string: "https://content.api.nebula.app/video_episodes/\(video.episodeId)/manifest.m3u8").require()
		components.queryItems = [
			URLQueryItem(name: "token", value: bearer),
			URLQueryItem(name: "platform", value: "ios"),
			URLQueryItem(name: "all_manifest", value: "true")
		]
		return try components.url.require()
	}
	
	@discardableResult
	func sendProgress(for video: Video, seconds: Int) async throws -> Video.Engagement {
		let url = try URL(string: "https://content.api.nebula.app/engagement/video/progress/").require()
		let progress = Progress(contentSlug: video.slug, value: seconds)
		return try await request(.post, url: url, body: progress, authorization: .bearer)
	}
	
	@discardableResult
	func markVideoAsWatched(_ video: Video) async throws -> Video.Engagement {
		let url = try URL(string: "https://content.api.nebula.app/engagement/video/progress/").require()
		let progress = Completed(contentSlug: video.slug)
		return try await request(.post, url: url, body: progress, authorization: .bearer)
	}
	
	func clearProgress(for video: Video) async throws {
		let url = try URL(string: "https://content.api.nebula.app/engagement/video/progress/\(video.slug)/").require()
		return try await request(.delete, url: url, authorization: .bearer)
	}
}
