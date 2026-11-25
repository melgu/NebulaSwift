//
//  BrowseTests.swift
//  NebulaSwiftLiveTests
//

import Foundation
import Testing
@testable import NebulaSwift

extension LiveTests {
	@MainActor @Suite struct Channels {
		private func testChannel(_ api: API) async throws -> Channel {
			try await api.channel(for: TestItems.channelSlug)
		}
		
		@Test func channel() async throws {
			let api = try await LiveSession.api()
			let channel = try await testChannel(api)
			
			#expect(channel.slug == TestItems.channelSlug)
			#expect(channel.title == TestItems.channelTitle)
			#expect(channel.channelId.hasPrefix("video_channel:"))
			#expect(channel.images.banner != nil)
		}
		
		@Test func allChannels() async throws {
			let api = try await LiveSession.api()
			let channels = try await api.allChannels(offset: 0, pageSize: 10)
			
			#expect(channels.count == 10)
		}
		
		@Test func videos() async throws {
			let api = try await LiveSession.api()
			let channel = try await testChannel(api)
			let videos = try await api.videos(for: channel, page: 1, pageSize: 5)
			
			#expect(videos.count == 5)
			#expect(videos.allSatisfy { $0.channelSlug == channel.slug })
			let dates = videos.map(\.publishedAt)
			#expect(dates == dates.sorted(by: >), "Newest first")
		}
		
		@Test func statistics() async throws {
			let api = try await LiveSession.api()
			let channel = try await testChannel(api)
			let statistics = try await api.statistics(for: channel)
			
			#expect(statistics.count > 50)
			#expect(statistics.duration > .seconds(statistics.count * 60))
		}
		
		@Test func engagement() async throws {
			let api = try await LiveSession.api()
			let channel = try await testChannel(api)
			
			_ = try await api.isFollowing(channel)
		}
		
		@Test func libraryChannels() async throws {
			let api = try await LiveSession.api()
			_ = try await api.libraryChannels(offset: 0, pageSize: 10)
		}
		
		@Test func podcasts() async throws {
			let api = try await LiveSession.api()
			let podcasts = try await api.allPodcasts(offset: 0, pageSize: 5)
			
			#expect(!podcasts.isEmpty)
		}
	}
	
	@MainActor @Suite struct Categories {
		private func testCategory(_ api: API) async throws -> NebulaSwift.Category {
			let categories = try await api.allCategories(offset: 0, pageSize: 100)
			return try #require(categories.first { $0.slug == TestItems.categorySlug })
		}
		
		@Test func categories() async throws {
			let api = try await LiveSession.api()
			let category = try await testCategory(api)
			
			#expect(category.title == "Engineering")
			#expect(category.id.hasPrefix("category:"))
		}
		
		@Test func videos() async throws {
			let api = try await LiveSession.api()
			let category = try await testCategory(api)
			let videos = try await api.videos(for: category, offset: 0, pageSize: 5)
			
			#expect(videos.count == 5)
		}
		
		@Test func channels() async throws {
			let api = try await LiveSession.api()
			let category = try await testCategory(api)
			let channels = try await api.channels(for: category, offset: 0, pageSize: 5)
			
			#expect(!channels.isEmpty)
		}
	}
	
	@MainActor @Suite struct Search {
		@Test func videos() async throws {
			let api = try await LiveSession.api()
			let videos = try await api.searchVideos(for: TestItems.searchTerm, offset: 0, pageSize: 5)
			
			#expect(!videos.isEmpty)
		}
		
		@Test func channels() async throws {
			let api = try await LiveSession.api()
			let channels = try await api.searchChannels(for: TestItems.channelTitle, offset: 0, pageSize: 5)
			
			#expect(channels.contains { $0.slug == TestItems.channelSlug })
		}
	}
	
	@MainActor @Suite struct Featured {
		private var page: FeaturedPage {
			get async throws {
				let api = try await LiveSession.api()
				let url = try #require(URL(string: "https://content.api.nebula.app/featured_pages/featured/"))
				return try await api.request(.get, url: url, authorization: .bearer)
			}
		}
		
		@Test func heroes() async throws {
			let page = try await page
			
			#expect(!page.heroes.isEmpty)
			for hero in page.heroes {
				#expect(hero.destination != nil, "\(hero.url)")
			}
		}
		
		/// The app leaves out rails it can't show, and those that fail to load, so the page looks fine either way.
		@Test func rails() async throws {
			let api = try await LiveSession.api()
			let page = try await page
			
			#expect(!page.rails.isEmpty)
			// Rails without a collection, like "Shared With You", hold personal content the app can't load anyway
			let unknown = page.rails.filter { $0.contentType == .unsupported && $0.collection != nil }
			#expect(unknown.isEmpty, "Rails of a kind the app doesn't know: \(unknown.map(\.title))")
			for rail in page.rails where rail.contentType != .unsupported && rail.contentType != .classes {
				#expect(rail.collection != nil, "\(rail.title)")
				#expect(try await api.items(for: rail) != nil, "\(rail.title)")
			}
		}
	}
}
