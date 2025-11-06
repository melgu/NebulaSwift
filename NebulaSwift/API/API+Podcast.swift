//
//  API+Podcast.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 23.07.22.
//

import Foundation

struct Podcast: Decodable {
	let id: String
	let type: String
	let slug: String
	let title: String
	let topLevelDescription: String?
	let assets: [String: URL]
	let website: URL?
	let patreon: URL?
	let twitter: URL?
	let instagram: URL?
	let facebook: URL?
	let merch: URL?
	let merchCollection: String?
	let apple: URL?
	let google: URL?
	let spotify: URL?
	let genreCategorySlug: String
	let genreCategoryTitle: String
	let genre: String
	let creator: String
	let rssUrl: URL
	let shareUrl: URL
	let engagement: Engagement
}
extension Podcast: Identifiable {}
extension Podcast: Equatable {}

extension Podcast {
	struct Engagement: Decodable, Equatable {
		let following: Bool
	}
}

extension API {
	func allPodcasts(offset: Int, pageSize: Int = 24) async throws -> [Podcast] {
		let url = try URL(string: "https://content.api.nebula.app/podcast/channels/?offset=\(offset)&page_size=\(pageSize)").require()
		let response: ListContainer<Podcast> = try await request(.get, url: url, authorization: .bearer)
		return response.results
	}
	
	@available(*, deprecated, message: "Use `allPodcasts(offset:pageSize:)` instead")
	@_disfavoredOverload
	func allPodcasts(page: Int, pageSize: Int = 24) async throws -> [Podcast] {
		try await allPodcasts(offset: (page - 1) * pageSize, pageSize: pageSize)
	}
}
