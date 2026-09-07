//
//  API+Featured.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 23.07.22.
//

import Foundation

// MARK: - API types

/// A page of the Featured tab, e.g. "Featured" or "News".
///
/// The rails only describe themselves, their contents are loaded from `collection`.
struct FeaturedPage: Decodable, Sendable {
	let id: String
	let slug: String
	let title: String
	let heroes: [Hero]
	let rails: [Rail]
}

struct Hero: Decodable, Equatable, Sendable {
	let id: String
	let title: String
	let shortDescription: String?
	let altText: String?
	let images: Images
	let url: URL
}
extension Hero: Identifiable {}

extension Hero {
	struct Images: Decodable, Equatable, Sendable {
		/// Landscape artwork, mostly 3:1 but also 2:1 and 16:9, so it needs cropping to a fixed shape.
		let backgroundWide: NebulaImage
		/// Roughly square artwork for portrait layouts. Not every hero has it.
		let backgroundNarrow: NebulaImage?
		let titleLogo: NebulaImage?
	}
	
	enum Destination: Hashable, Sendable {
		case video(slug: String)
		case channel(slug: String)
	}
	
	/// Heroes only link to the website, so the target has to be derived from the link.
	///
	/// `https://nebula.tv/videos/<slug>` is an episode, every other link starts with a channel's
	/// slug, optionally followed by a season or playlist the app doesn't have a screen for.
	var destination: Destination? {
		let components = url.pathComponents.filter { $0 != "/" }
		guard let first = components.first else { return nil }
		guard first == "videos" else { return .channel(slug: first) }
		guard let slug = components.dropFirst().first else { return nil }
		return .video(slug: slug)
	}
}

struct Rail: Decodable, Sendable {
	let id: String
	let title: String
	let contentType: ContentType
	let collection: URL?
	let viewAll: URL?
}

extension Rail {
	enum ContentType: String, Decodable, Sendable {
		case videoEpisodes = "video_episodes"
		case videoChannels = "video_channels"
		case podcastChannels = "podcast_channels"
		case classes
		case unsupported
		
		init(from decoder: Decoder) throws {
			let rawValue = try decoder.singleValueContainer().decode(String.self)
			self = ContentType(rawValue: rawValue) ?? .unsupported
		}
	}
}

// MARK: - View model

/// A row of the Featured tab, with its contents already loaded.
struct Feature: Equatable, Sendable {
	let id: String
	let title: String
	let viewAllURL: URL?
	let items: Content
}
extension Feature: Identifiable {}

extension Feature {
	enum Content: Equatable, Sendable {
		case heroes([Hero])
		case videos([Video])
		case channels([Channel])
		case podcasts([Podcast])
		case classes
	}
}

extension API {
	func featured(page slug: String = "featured") async throws -> [Feature] {
		let url = try URL(string: "https://content.api.nebula.app/featured_pages/\(slug)/").require()
		let page: FeaturedPage = try await request(.get, url: url, authorization: .bearer)
		
		// The rails are loaded at once, and a rail the app can't show, or that failed to load, is
		// left out instead of taking the whole page down with it.
		//
		// A task group would be the natural fit, but every variant of it fails to compile with
		// "pattern that the region-based isolation checker does not understand how to check.
		// Please file a bug" (Xcode 27.0 Beta 6). Worth another try on a later toolchain:
		//
		//	let loaded = try await withThrowingTaskGroup(of: (String, Feature?).self) { group in
		//		for rail in page.rails {
		//			group.addTask { @MainActor in
		//				guard let items = try? await self.items(for: rail) else { return (rail.id, nil) }
		//				return (rail.id, Feature(id: rail.id, title: rail.title, viewAllURL: rail.viewAll, items: items))
		//			}
		//		}
		//		return try await group.reduce(into: [:]) { $0[$1.0] = $1.1 }
		//	}
		//	let rails = page.rails.compactMap { loaded[$0.id] }
		let loading = page.rails.map { rail in
			Task {
				guard let items = try? await self.items(for: rail) else { return nil as Feature? }
				return Feature(id: rail.id, title: rail.title, viewAllURL: rail.viewAll, items: items)
			}
		}
		var rails: [Feature] = []
		for task in loading {
			guard let feature = await task.value else { continue }
			rails.append(feature)
		}
		
		guard !page.heroes.isEmpty else { return rails }
		return [Feature(id: page.id, title: page.title, viewAllURL: nil, items: .heroes(page.heroes))] + rails
	}
	
	/// The contents of a rail, or `nil` if there are none to show.
	private func items(for rail: Rail) async throws -> Feature.Content? {
		guard rail.contentType != .classes else { return .classes }
		guard let collection = rail.collection else { return nil }
		
		switch rail.contentType {
		case .videoEpisodes:
			// Collections answer with a bare list, and without engagement.
			let videos: [Video] = try await request(.get, url: collection, authorization: .bearer)
			guard !videos.isEmpty else { return nil }
			return .videos(try await withEngagement(videos))
		case .videoChannels:
			let channels: [Channel] = try await request(.get, url: collection, authorization: .bearer)
			guard !channels.isEmpty else { return nil }
			return .channels(try await withEngagement(channels))
		case .podcastChannels:
			let podcasts: [Podcast] = try await request(.get, url: collection, authorization: .bearer)
			guard !podcasts.isEmpty else { return nil }
			return .podcasts(podcasts)
		case .classes, .unsupported:
			return nil
		}
	}
}
