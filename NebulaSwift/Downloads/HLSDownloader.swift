//
//  HLSDownloader.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 05.10.26.
//

import Foundation

enum DownloadProgress: Equatable, Sendable {
	case downloading(Double)
	/// Putting the downloaded renditions into one file.
	case processing(Double)
}

struct VideoDownloadRequest: Sendable {
	let manifestURL: URL
	/// The highest resolution to download, or `nil` for the best one.
	let maxHeight: Int?
	/// Keeps what was downloaded so far, so a later attempt with the same directory continues from there.
	let workDirectory: URL
	let outputURL: URL
	let metadata: MP4Muxer.Metadata
}

/// Downloads a video into a single MP4 file.
///
/// Keeps the download manager independent of how videos are downloaded.
protocol VideoDownloader: Sendable {
	/// - Returns: The downloaded video's height in pixels.
	func download(_ request: VideoDownloadRequest, progress: @escaping @Sendable (DownloadProgress) -> Void) async throws -> Int
}

/// Downloads the segments of an HLS stream with fragmented MP4 segments, then muxes them into an MP4 file.
///
/// Downloads every audio and subtitle rendition, so they can be picked in the player.
struct HLSDownloader: VideoDownloader {
	/// How many segments of a rendition load at the same time.
	private static let parallelSegments = 4
	private static let attempts = 4
	
	func download(_ request: VideoDownloadRequest, progress: @escaping @Sendable (DownloadProgress) -> Void) async throws -> Int {
		let fileManager = FileManager.default
		try fileManager.createDirectory(at: request.workDirectory, withIntermediateDirectories: true)
		
		// The stream's URLs are signed for a limited time, so they're always resolved anew
		let (masterData, masterURL) = try await fetch(request.manifestURL)
		let master = try HLSPlaylist.Master(String(decoding: masterData, as: UTF8.self), baseURL: masterURL)
		let variant = master.variant(maxHeight: request.maxHeight)
		let audioRenditions = master.renditions(.audio, inGroup: variant.audioGroup)
		let subtitleRenditions = master.renditions(.subtitles, inGroup: variant.subtitlesGroup)
		
		var tracks = [Track(name: "video", path: variant.path, playlistURL: variant.url)]
		for (index, rendition) in audioRenditions.enumerated() {
			tracks.append(Track(name: "audio-\(index)", path: rendition.path, playlistURL: rendition.url))
		}
		let plans = try await withThrowingTaskGroup(of: (Int, TrackPlan).self) { group in
			for (index, track) in tracks.enumerated() {
				group.addTask {
					let (data, url) = try await fetch(track.playlistURL)
					let media = try HLSPlaylist.Media(String(decoding: data, as: UTF8.self), baseURL: url)
					return (index, TrackPlan(track: track, urls: [media.initializationSegment].compactMap { $0 } + media.segments))
				}
			}
			var plans: [(Int, TrackPlan)] = []
			for try await plan in group {
				plans.append(plan)
			}
			return plans.sorted { $0.0 < $1.0 }.map(\.1)
		}
		
		let subtitles = try await withThrowingTaskGroup(of: (Int, MP4Muxer.SubtitleTrack).self) { group in
			for (index, rendition) in subtitleRenditions.enumerated() {
				group.addTask {
					let (data, url) = try await fetch(rendition.url)
					let media = try HLSPlaylist.Media(String(decoding: data, as: UTF8.self), baseURL: url)
					var subtitles = WebVTT()
					for segment in media.segments {
						subtitles.append(String(decoding: try await fetch(segment).data, as: UTF8.self))
					}
					return (index, MP4Muxer.SubtitleTrack(subtitles: subtitles, language: rendition.language))
				}
			}
			var subtitles: [(Int, MP4Muxer.SubtitleTrack)] = []
			for try await track in group {
				subtitles.append(track)
			}
			return subtitles.sorted { $0.0 < $1.0 }.map(\.1)
		}
		
		let counter = ProgressCounter(total: plans.reduce(0) { $0 + $1.urls.count }, progress: progress)
		try await withThrowingTaskGroup(of: Void.self) { group in
			for plan in plans {
				group.addTask {
					try await download(plan, in: request.workDirectory, counter: counter)
				}
			}
			try await group.waitForAll()
		}
		
		try Task.checkCancellation()
		progress(.processing(0))
		let audio = zip(audioRenditions, plans.dropFirst()).map { rendition, plan in
			MP4Muxer.AudioTrack(url: plan.track.fileURL(in: request.workDirectory), language: rendition.language, isDefault: rendition.isDefault)
		}
		try await MP4Muxer.mux(
			video: plans[0].track.fileURL(in: request.workDirectory),
			audio: audio,
			subtitles: subtitles,
			metadata: request.metadata,
			to: request.outputURL
		) { fraction in
			progress(.processing(fraction))
		}
		return variant.height
	}
	
	/// Appends the rendition's segments to its file in order, continuing after the ones already there.
	private func download(_ plan: TrackPlan, in directory: URL, counter: ProgressCounter) async throws {
		let stateURL = plan.track.stateURL(in: directory)
		var state = (try? JSONDecoder().decode(TrackState.self, from: Data(contentsOf: stateURL))) ?? TrackState(path: plan.track.path)
		if state.path != plan.track.path || state.segments > plan.urls.count {
			// Another quality, or the stream changed
			state = TrackState(path: plan.track.path)
		}
		var file = try FragmentedMP4File(url: plan.track.fileURL(in: directory), size: state.size, fragmentCount: state.fragments)
		await counter.add(state.segments)
		
		try await withThrowingTaskGroup(of: (Int, Data).self) { group in
			var nextToFetch = state.segments
			var fetched: [Int: Data] = [:]
			
			func fetchMore() {
				while nextToFetch < plan.urls.count, nextToFetch < state.segments + Self.parallelSegments {
					let index = nextToFetch
					let url = plan.urls[index]
					group.addTask {
						(index, try await fetch(url).data)
					}
					nextToFetch += 1
				}
			}
			
			fetchMore()
			while let (index, data) = try await group.next() {
				fetched[index] = data
				while let data = fetched.removeValue(forKey: state.segments) {
					try file.append(data)
					state.segments += 1
					state.size = file.size
					state.fragments = file.fragmentCount
					try JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
					await counter.add(1)
				}
				fetchMore()
			}
		}
	}
	
	/// Retries network failures, but not responses that won't change.
	private func fetch(_ url: URL) async throws -> (data: Data, url: URL) {
		var attempt = 1
		while true {
			do {
				let (data, response) = try await URLSession.shared.data(from: url)
				guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
				switch response.statusCode {
				case 200:
					// Relative addresses in a playlist refer to where any redirect led
					return (data, response.url ?? url)
				case 401, 403:
					throw DownloadError.accessDenied
				default:
					throw DownloadError.invalidServerResponse(statusCode: response.statusCode)
				}
			} catch {
				guard attempt < Self.attempts, Self.isTransient(error) else { throw error }
				try await Task.sleep(for: .seconds(attempt * 2))
				attempt += 1
			}
		}
	}
	
	private static func isTransient(_ error: Error) -> Bool {
		switch error {
		case let error as URLError:
			error.code != .cancelled
		case DownloadError.invalidServerResponse(let statusCode):
			statusCode >= 500
		default:
			false
		}
	}
}

// MARK: - Tracks

private extension HLSDownloader {
	struct Track: Sendable {
		let name: String
		/// The playlist's address as written in the multivariant playlist, which tells whether a partial download is of the same rendition.
		let path: String
		let playlistURL: URL
		
		func fileURL(in directory: URL) -> URL {
			directory.appending(path: "\(name).mp4")
		}
		
		func stateURL(in directory: URL) -> URL {
			directory.appending(path: "\(name).json")
		}
	}
	
	struct TrackPlan: Sendable {
		let track: Track
		/// The initialization segment, followed by the media segments.
		let urls: [URL]
	}
	
	/// How far a rendition's download got, saved after every segment.
	struct TrackState: Codable {
		let path: String
		var segments = 0
		var size: UInt64 = 0
		var fragments: UInt32 = 0
	}
	
	actor ProgressCounter {
		private let total: Int
		private var completed = 0
		private let progress: @Sendable (DownloadProgress) -> Void
		
		init(total: Int, progress: @escaping @Sendable (DownloadProgress) -> Void) {
			self.total = total
			self.progress = progress
		}
		
		func add(_ count: Int) {
			guard count > 0, total > 0 else { return }
			completed += count
			progress(.downloading(Double(completed) / Double(total)))
		}
	}
}
