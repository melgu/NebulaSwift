//
//  APIModelTests.swift
//  NebulaSwiftTests
//

import Foundation
import Testing
@testable import NebulaSwift

/// Decodes like ``API/decoder``.
private let decoder: JSONDecoder = {
	let decoder = JSONDecoder()
	decoder.keyDecodingStrategy = .convertFromSnakeCase
	decoder.dateDecodingStrategy = .iso8601
	return decoder
}()

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
	try decoder.decode(type, from: Data(json.utf8))
}

private let imageJSON = #"{"src": "https://images.nebula.tv/image.webp", "width": 1280, "height": 720}"#

// MARK: - Featured

struct HeroTests {
	private func hero(url: String) throws -> Hero {
		try decode(Hero.self, """
			{
				"id": "hero:1",
				"title": "Title",
				"short_description": null,
				"alt_text": null,
				"images": {"background_wide": \(imageJSON), "background_narrow": null, "title_logo": null},
				"url": "\(url)"
			}
			""")
	}
	
	@Test(arguments: [
		("https://nebula.tv/videos/some-episode", Hero.Destination.video(slug: "some-episode")),
		("https://nebula.tv/videos/some-episode/", .video(slug: "some-episode")),
		("https://nebula.tv/realengineering", .channel(slug: "realengineering")),
		("https://nebula.tv/realengineering/season/2", .channel(slug: "realengineering")),
	])
	func destination(url: String, destination: Hero.Destination) throws {
		#expect(try hero(url: url).destination == destination)
	}
	
	@Test(arguments: ["https://nebula.tv/videos", "https://nebula.tv/", "https://nebula.tv"])
	func noDestination(url: String) throws {
		#expect(try hero(url: url).destination == nil)
	}
}

struct RailTests {
	private func rail(contentType: String) throws -> Rail {
		try decode(Rail.self, """
			{"id": "rail:1", "title": "Rail", "content_type": "\(contentType)", "collection": null, "view_all": null}
			""")
	}
	
	@Test func knownContentType() throws {
		#expect(try rail(contentType: "video_episodes").contentType == .videoEpisodes)
		#expect(try rail(contentType: "podcast_channels").contentType == .podcastChannels)
	}
	
	@Test func unknownContentTypeDoesntFailThePage() throws {
		#expect(try rail(contentType: "audio_books").contentType == .unsupported)
	}
}

// MARK: - Images

struct ImageTests {
	private struct Container: Decodable {
		let image: NebulaImageResource
	}
	
	@Test func resourceDecodesObjectAndString() throws {
		let object = try decode(Container.self, #"{"image": {"original": "https://images.nebula.tv/a.png"}}"#)
		let string = try decode(Container.self, #"{"image": "https://images.nebula.tv/a.png"}"#)
		
		#expect(object.image.original.absoluteString == "https://images.nebula.tv/a.png")
		#expect(string.image.original == object.image.original)
	}
	
	@Test func scaledImageAddsWidth() throws {
		let image = try decode(NebulaImage.self, imageJSON)
		
		#expect(image[400].absoluteString == "https://images.nebula.tv/image.webp?width=400")
	}
}

// MARK: - Video

struct VideoTests {
	private func video(categories: String) throws -> Video {
		try decode(Video.self, """
			{
				"id": "video_episode:1",
				"slug": "some-episode",
				"title": "Title",
				"description": "Description",
				"short_description": "Short",
				"duration": 600,
				"published_at": "2026-01-02T03:04:05Z",
				"channel_slug": "channel",
				"channel_title": "Channel",
				"images": {"channel_avatar": \(imageJSON), "thumbnail": \(imageJSON)},
				"attributes": ["is_nebula_original"],
				"share_url": "https://nebula.tv/videos/some-episode"
				\(categories)
			}
			""")
	}
	
	@Test func categorySlugsOfFullEpisodes() throws {
		#expect(try video(categories: #", "category_slugs": ["science"], "categories": ["ignored"]"#).categorySlugs == ["science"])
	}
	
	@Test func categorySlugsOfTrimmedEpisodes() throws {
		#expect(try video(categories: #", "categories": ["history"]"#).categorySlugs == ["history"])
	}
	
	@Test func categorySlugsWithoutAny() throws {
		#expect(try video(categories: "").categorySlugs == [])
	}
	
	/// Downloads keep their videos in `Downloads.json`, written with the default coding.
	@Test func survivesTheDownloadIndex() throws {
		var video = try video(categories: #", "category_slugs": ["science"]"#)
		video.engagement = .init(contentSlug: video.slug, updatedAt: nil, progress: 30, completed: false, watchLater: true)
		
		let decoded = try JSONDecoder().decode(Video.self, from: JSONEncoder().encode(video))
		
		#expect(decoded == video)
		#expect(decoded.categorySlugs == ["science"])
	}
}

// MARK: - Errors

@MainActor
struct APIErrorTests {
	@Test(arguments: [
		(#"{"detail": "Invalid token."}"#, "Invalid token."),
		(#"{"password": ["Too short."], "non_field_errors": ["Unable to log in with provided credentials."]}"#, "Unable to log in with provided credentials.\nToo short."),
		(#"{"email": ["Enter a valid email address.", "Required."]}"#, "Enter a valid email address.\nRequired."),
	])
	func serverMessage(json: String, message: String) {
		#expect(API.serverMessage(in: Data(json.utf8)) == message)
	}
	
	@Test(arguments: [#"{}"#, #"{"detail": 5}"#, "<html>Bad Gateway</html>", #"["not", "an", "object"]"#])
	func noServerMessage(body: String) {
		#expect(API.serverMessage(in: Data(body.utf8)) == nil)
	}
	
	@Test func unauthorized() {
		#expect(APIError.invalidServerResponse(errorCode: 401, message: nil).isUnauthorized)
		#expect(APIError.invalidServerResponse(errorCode: 403, message: nil).isUnauthorized)
		#expect(!APIError.invalidServerResponse(errorCode: 404, message: nil).isUnauthorized)
		#expect(!APIError.networkIssues.isUnauthorized)
	}
	
	@Test func descriptionPrefersServerMessage() {
		#expect(APIError.invalidServerResponse(errorCode: 400, message: "Wrong password").errorDescription == "Wrong password")
		#expect(APIError.invalidServerResponse(errorCode: 400, message: nil).errorDescription?.contains("400") == true)
	}
}
