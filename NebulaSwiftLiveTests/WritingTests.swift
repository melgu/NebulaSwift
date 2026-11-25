//
//  WritingTests.swift
//  NebulaSwiftLiveTests
//

import Foundation
import Testing
@testable import NebulaSwift

extension LiveTests {
	/// Tests of the endpoints that change the account. Each one puts things back the way they were, but a failure
	/// midway can leave a change behind, so they only run when enabled here.
	@MainActor @Suite(.disabled("Changes the account. Enable to check the writing endpoints."))
	struct Writing {
		private func engagement(of video: Video, _ api: API) async throws -> Video.Engagement? {
			try await api.withEngagement([video]).first?.engagement
		}
		
		@Test func watchLater() async throws {
			let api = try await LiveSession.api()
			let video = try #require(try await api.allVideos(offset: 0, pageSize: 1).first)
			let wasOnWatchLater = try await engagement(of: video, api)?.watchLater ?? false
			
			if wasOnWatchLater {
				try await api.removeVideoFromWatchLater(video)
				#expect(try await engagement(of: video, api)?.watchLater ?? false == false)
				try await api.addVideoToWatchLater(video)
			} else {
				try await api.addVideoToWatchLater(video)
				#expect(try await engagement(of: video, api)?.watchLater == true)
				try await api.removeVideoFromWatchLater(video)
			}
			#expect(try await engagement(of: video, api)?.watchLater ?? false == wasOnWatchLater)
		}
		
		@Test func follow() async throws {
			let api = try await LiveSession.api()
			let channel = try await api.channel(for: TestItems.channelSlug)
			let wasFollowing = try await api.isFollowing(channel)
			
			if wasFollowing {
				try await api.unfollow(channel)
				#expect(try await !api.isFollowing(channel))
				try await api.follow(channel)
			} else {
				try await api.follow(channel)
				#expect(try await api.isFollowing(channel))
				try await api.unfollow(channel)
			}
			#expect(try await api.isFollowing(channel) == wasFollowing)
		}
		
		/// Uses a video without progress, which clearing returns to exactly that.
		@Test func progress() async throws {
			let api = try await LiveSession.api()
			let videos = try await api.allVideos(offset: 0, pageSize: 20)
			let video = try #require(videos.first { ($0.engagement?.progress ?? 0) == 0 && $0.engagement?.updatedAt == nil })
			
			let sent = try await api.sendProgress(for: video, seconds: 30)
			#expect(sent.progress == 30)
			#expect(try await engagement(of: video, api)?.progress == 30)
			
			try await api.markVideoAsWatched(video)
			#expect(try await engagement(of: video, api)?.completed == true)
			
			try await api.clearProgress(for: video)
			#expect(try await engagement(of: video, api)?.progress ?? 0 == 0)
			// Clearing again finds nothing to clear, which isn't an error
			try await api.clearProgress(for: video)
		}
	}
}
