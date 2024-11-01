//
//  API+Video.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 17.11.21.
//

import Foundation

// MARK: Info

struct Video: Codable, Equatable {
	let slug: String
	let title: String
	let description: String
	let shortDescription: String
	let duration: Int
	let publishedAt: Date
	let channelSlug: String
	let channelSlugs: [String]
	let channelTitle: String
	let categorySlugs: [String]
	let assets: Assets
	let attributes: [Attribute]
	let shareUrl: URL
//	let channel: NSNull
	let engagement: Engagement?
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
	struct Assets: Codable, Equatable {
		let channelAvatar: [String: NebulaImageResource]
		let thumbnail: [String: NebulaImageResource]
	}
	
	enum Attribute: String, Codable, Equatable {
		case freeSampleEligible = "free_sample_eligible"
		case isNebulaPlus = "is_nebula_plus"
		case isNebulaOriginal = "is_nebula_original"
		case isNebulaFirst = "is_nebula_first"
	}
	
	struct Engagement: Codable, Equatable, Hashable {
		let contentSlug: String
		let updatedAt: Date
		let progress: Int
		let completed: Bool
		let watchLater: Bool
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

// MARK: - Stream

struct VideoStream: Decodable {
	let manifest: URL
//	let download: URL
	let iframe: URL?
//	let bif: Bif
	let subtitles: [Subtitle]
}

//struct Bif: Decodable {
//	let hd: URL
//	let sd: URL
//	let fhd: URL
//}

struct Subtitle: Decodable {
	let languageCode: String
	let url: URL
	let language: String
}

extension API {
	func allVideos(offset: Int, pageSize: Int = 24) async throws -> [Video] {
		let url = URL(string: "https://content.watchnebula.com/video/?offset=\(offset)&page_size=\(pageSize)")!
		let response: ListContainer<Video> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	@available(*, deprecated, message: "Use `allVideos(offset:pageSize:)` instead")
	@_disfavoredOverload
	func allVideos(page: Int, pageSize: Int = 24) async throws -> [Video] {
		try await allVideos(offset: (page - 1) * pageSize, pageSize: pageSize)
	}
	
	func video(for slug: String) async throws -> Video {
		let url = URL(string: "https://content.watchnebula.com/video/\(slug)/")!
		return try await request(.get, url: url, authorization: .bearer)
	}
	
	func stream(for video: Video) async throws -> VideoStream {
		let url = URL(string: "https://content.watchnebula.com/video/\(video.slug)/stream/")!
		return try await request(.get, url: url, authorization: .bearer)
	}
	
	@discardableResult
	func sendProgress(for video: Video, seconds: Int) async throws -> Video.Engagement {
		let url = URL(string: "https://content.watchnebula.com/engagement/video/progress/")!
		let progress = Progress(contentSlug: video.slug, value: seconds)
		return try await request(.post, url: url, body: progress, authorization: .bearer)
	}
	
	@discardableResult
	func markVideoAsWatched(_ video: Video) async throws -> Video.Engagement {
		let url = URL(string: "https://content.watchnebula.com/engagement/video/progress/")!
		let progress = Completed(contentSlug: video.slug)
		return try await request(.post, url: url, body: progress, authorization: .bearer)
	}
	
	func clearProgress(for video: Video) async throws {
		let url = URL(string: "https://content.api.nebula.app/engagement/video/progress/\(video.slug)/")!
		return try await request(.delete, url: url, authorization: .bearer)
	}
}
