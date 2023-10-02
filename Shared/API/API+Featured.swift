//
//  API+Featured.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 23.07.22.
//

import Foundation

struct Feature: Decodable {
	let id: String
	let title: String
	let viewAllURL: URL?
	let items: Content
	
	enum CodingKeys: CodingKey {
		case type
		case id
		case title
		case viewAllURL
		case items
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.id = try container.decode(String.self, forKey: .id)
		self.title = try container.decode(String.self, forKey: .title)
		self.viewAllURL = try container.decodeIfPresent(URL.self, forKey: .viewAllURL)
		
		let type = try container.decode(Feature.FeatureType.self, forKey: .type)
		switch type {
		case .heroes:
			let items = try container.decode([Hero].self, forKey: .items)
			self.items = .heroes(items)
		case .latestVideos:
			let items = try container.decode([Video].self, forKey: .items)
			self.items = .latestVideos(items)
		case .videoChannels:
			let items = try container.decode([Channel].self, forKey: .items)
			self.items = .videoChannels(items)
		case .featuredCreators:
			let items = try container.decode([Channel].self, forKey: .items)
			self.items = .featuredCreators(items)
		case .podcastChannels:
			let items = try container.decode([Podcast].self, forKey: .items)
			self.items = .podcastChannels(items)
		case .classes:
			self.items = .classes
		}
	}
}
extension Feature: Identifiable {}
extension Feature: Equatable {}

extension Feature {
	private enum FeatureType: String, Decodable {
		case heroes
		case latestVideos = "latest_videos"
		case videoChannels = "video_channels"
		case featuredCreators = "featured_creators"
		case podcastChannels = "podcast_channels"
		case classes
	}
	
	enum Content: Equatable {
		case heroes([Hero])
		case latestVideos([Video])
		case videoChannels([Channel])
		case featuredCreators([Channel])
		case podcastChannels([Podcast])
		case classes
	}
}

struct Hero: Decodable, Equatable {
	let id: String
	let type: String
	let slug: String
	let title: String
	let assets: Assets
	let url: URL
	let altText: String
}
extension Hero: Identifiable {}

extension Hero {
	struct Assets: Decodable, Equatable {
		let hero: [String: NebulaImageResource]
		let mobileHero: NebulaImageResource
	}
}

extension API {
	func featured() async throws -> [Feature] {
		let url = URL(string: "https://content.api.nebula.app/featured/")!
		return try await request(.get, url: url, authorization: .bearer)
	}
}
