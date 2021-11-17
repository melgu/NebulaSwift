//
//  API+Video.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 17.11.21.
//

import Foundation

struct VideoList: Decodable {
	let next: String?
	let previous: String?
	let results: [Video]
}

struct Video: Decodable {
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
	let engagement: Engagement?
	let zypeId: String
}
extension Video: Identifiable {
	var id: String { zypeId }
}

struct Assets: Decodable {
	let channelAvatar: [String: ChannelAvatar]
	let thumbnail: [String: Thumbnail]
}

struct ChannelAvatar: Decodable {
	let original: URL
	let webp: URL
}

struct Thumbnail: Decodable {
	let original: URL
}

enum Attribute: Decodable {
	case freeSampleEligible
	case isNebulaPlus
}

struct Engagement: Decodable {
//	let updatedAt: Date
	let progress: Int
}
