//
//  API+Video.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 17.11.21.
//

import Foundation

// MARK: Info

struct VideoList: Decodable {
	let next: String?
	let previous: String?
	let results: [Video]
}

struct Video: Decodable, Equatable {
	let slug: String
	let title: String
	let description: String
	let shortDescription: String
	let duration: Int
//	let publishedAt: Date
	let channelSlug: String
	let channelSlugs: [String]
	let channelTitle: String
	let categorySlugs: [String]
	let assets: Assets
//	let attributes: [Attribute]
	let shareUrl: URL
//	let channel: NSNull
	let engagement: Engagement
	let zypeId: String
}
extension Video: Identifiable {
	var id: String { zypeId }
}

struct Assets: Decodable, Equatable {
	let channelAvatar: [String: ChannelAvatar]
	let thumbnail: [String: Thumbnail]
}

struct ChannelAvatar: Decodable, Equatable {
	let original: URL
	let webp: URL
}

struct Thumbnail: Decodable, Equatable {
	let original: URL
}

enum Attribute: Decodable, Equatable {
	case freeSampleEligible
	case isNebulaPlus
}

struct Engagement: Decodable, Equatable {
	let contentSlug: String
	let updatedAt: Date
	let progress: Int
	let completed: Bool
	let watchLater: Bool
}

struct Progress: Encodable {
	let contentSlug: String
	let value: Int
}

// MARK: - Stream

extension API {
	func video(for slug: String) async throws -> Video {
		let url = URL(string: "https://content.watchnebula.com/video/\(slug)/")!
		return try await request(.get, url: url, parameters: [:], authorization: .bearer)
	}
	
	func stream(for video: Video) async throws -> VideoStream {
		let url = URL(string: "https://content.watchnebula.com/video/\(video.slug)/stream/")!
		let parameters: [String: String] = ["page": "1"]
		return try await request(.get, url: url, parameters: parameters, authorization: .bearer)
	}
	
	@discardableResult
	func sendProgress(for video: Video, seconds: Int) async throws -> Engagement {
		let url = URL(string: "https://content.watchnebula.com/engagement/video/progress/")!
		let progress = Progress(contentSlug: video.slug, value: seconds)
		print(String(data: (try! encoder.encode(progress)), encoding: .utf8)!)
		return try await request(.post, url: url, parameters: [:], body: progress, authorization: .bearer)
	}
}


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
