//
//  VideoTests.swift
//  NebulaSwiftLiveTests
//

import Foundation
import Testing
@testable import NebulaSwift

extension LiveTests {
	@MainActor @Suite struct Videos {
		@Test func allVideos() async throws {
			let api = try await LiveSession.api()
			let first = try await api.allVideos(offset: 0, pageSize: 5)
			let second = try await api.allVideos(offset: 5, pageSize: 5)
			
			#expect(first.count == 5)
			#expect(second.count == 5)
			#expect(Set(first.map(\.slug)).isDisjoint(with: second.map(\.slug)))
		}
		
		/// The fields the older endpoints lack, which the app falls back from silently.
		@Test func newerFieldsArePresent() async throws {
			let api = try await LiveSession.api()
			let videos = try await api.allVideos(offset: 0, pageSize: 10)
			
			for video in videos {
				#expect(video.type == "video_episode", "\(video.slug)")
				#expect(video.durationToComplete != nil, "\(video.slug)")
				#expect(video.channelId != nil, "\(video.slug)")
				#expect(video.appPath != nil, "\(video.slug)")
				#expect(!video.categorySlugs.isEmpty, "\(video.slug)")
			}
		}
		
		@Test func video() async throws {
			let api = try await LiveSession.api()
			let listed = try #require(try await api.allVideos(offset: 0, pageSize: 1).first)
			let video = try await api.video(for: listed.slug)
			
			#expect(video.slug == listed.slug)
			#expect(video.episodeId == listed.episodeId)
			#expect(video.title == listed.title)
			#expect(video.duration > 0)
		}
		
		@Test func engagement() async throws {
			let api = try await LiveSession.api()
			let videos = try await api.allVideos(offset: 0, pageSize: 3)
			let withEngagement = try await api.withEngagement(videos.map { video in
				var video = video
				video.engagement = nil
				return video
			})
			
			// The endpoint may leave out videos nobody engaged with
			#expect(withEngagement.allSatisfy { $0.engagement == nil || $0.engagement?.contentSlug == $0.slug })
		}
		
		@Test func history() async throws {
			let api = try await LiveSession.api()
			let videos = try await api.historyVideos(page: 1, pageSize: 10)
			
			#expect(videos.allSatisfy { $0.engagement?.updatedAt != nil })
			let dates = videos.compactMap(\.engagement?.updatedAt)
			#expect(dates == dates.sorted(by: >), "Most recently watched first")
		}
		
		@Test func continueWatching() async throws {
			let api = try await LiveSession.api()
			let videos = try await api.continueVideos(page: 1, pageSize: 10)
			
			#expect(videos.allSatisfy { $0.engagement?.completed == false })
		}
		
		@Test func watchLater() async throws {
			let api = try await LiveSession.api()
			let videos = try await api.watchLaterVideos(page: 1, pageSize: 10)
			let statistics = try await api.watchLaterStatistics()
			
			#expect(statistics.count >= videos.count)
		}
		
		@Test func libraryVideos() async throws {
			let api = try await LiveSession.api()
			_ = try await api.libraryVideos(offset: 0, pageSize: 10)
		}
	}
	
	/// What the downloader expects from the streams.
	@MainActor @Suite struct Streams {
		private func fetch(_ url: URL) async throws -> (text: String, url: URL) {
			let (data, response) = try await URLSession.shared.data(from: url)
			let httpResponse = try #require(response as? HTTPURLResponse)
			#expect(httpResponse.statusCode == 200, "\(url)")
			return (String(decoding: data, as: UTF8.self), try #require(httpResponse.url))
		}
		
		@Test func manifest() async throws {
			let api = try await LiveSession.api()
			let video = try #require(try await api.allVideos(offset: 0, pageSize: 1).first)
			let (text, url) = try await fetch(api.manifestURL(for: video))
			let master = try HLSPlaylist.Master(text, baseURL: url)
			
			let best = master.variant(maxHeight: nil)
			#expect(best.height >= 1080)
			// The variants carry no audio of their own
			#expect(!master.renditions(.audio, inGroup: best.audioGroup).isEmpty)
			
			// The smallest one, to keep the download short
			let variant = master.variant(maxHeight: 0)
			let media = try HLSPlaylist.Media(try await fetch(variant.url).text, baseURL: variant.url)
			let initializationSegment = try #require(media.initializationSegment)
			let segment = try #require(media.segments.first)
			
			let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
			try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
			defer { try? FileManager.default.removeItem(at: directory) }
			var file = try FragmentedMP4File(url: directory.appending(path: "video.mp4"), size: 0, fragmentCount: 0)
			try file.append(try await URLSession.shared.data(from: initializationSegment).0)
			#expect(file.fragmentCount == 0)
			try file.append(try await URLSession.shared.data(from: segment).0)
			#expect(file.fragmentCount >= 1)
		}
		
		@Test func subtitles() async throws {
			let api = try await LiveSession.api()
			// Recent videos are more likely to have subtitles
			let videos = try await api.allVideos(offset: 0, pageSize: 10)
			var found = false
			for video in videos {
				let (text, url) = try await fetch(api.manifestURL(for: video))
				let master = try HLSPlaylist.Master(text, baseURL: url)
				let variant = master.variant(maxHeight: nil)
				guard let rendition = master.renditions(.subtitles, inGroup: variant.subtitlesGroup).first else { continue }
				
				let playlist = try await fetch(rendition.url)
				let media = try HLSPlaylist.Media(playlist.text, baseURL: playlist.url)
				var subtitles = WebVTT()
				subtitles.append(try await fetch(try #require(media.segments.first)).text)
				#expect(!subtitles.cues.isEmpty, "\(video.slug)")
				found = true
				break
			}
			#expect(found, "None of the latest videos has subtitles")
		}
	}
}
