//
//  API+Video.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 17.11.21.
//

import Foundation

// MARK: Info

struct Video: Decodable, Equatable {
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

extension Video {
	struct Assets: Decodable, Equatable {
		let channelAvatar: [String: Channel.Avatar]
		let thumbnail: [String: Thumbnail]
	}
	
	struct Thumbnail: Decodable, Equatable {
		let original: URL
	}
	
	enum Attribute: String, Decodable, Equatable {
		case freeSampleEligible = "free_sample_eligible"
		case isNebulaPlus = "is_nebula_plus"
		case isNebulaOriginal = "is_nebula_original"
	}

	struct Engagement: Decodable, Equatable {
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

// MARK: - Stream

struct VideoStream: Decodable {
	let manifest: URL
	let download: URL
	let iframe: URL
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
	func allVideos(page: Int, pageSize: Int = 24) async throws -> [Video] {
		let url = URL(string: "https://content.watchnebula.com/video/?page=\(page)&page_size=\(pageSize)")!
		let response: ListContainer<Video> = try await request(.get, url: url, authorization: .bearer)
		return response.results
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
}
