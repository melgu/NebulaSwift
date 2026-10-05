//
//  ProgressSync.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 05.10.26.
//

import Foundation
import Network
import OSLog
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Remembers the watch progress until the server has it, so it survives being offline.
///
/// Each update is saved before it's sent, and only forgotten once the server confirmed it.
/// Until then, playback resumes from it, and it's sent again once the device is back online.
@MainActor @Observable
final class ProgressSync {
	struct Entry: Codable, Equatable {
		let video: Video
		let state: Player.WatchState
		let seconds: Int
		let recordedAt: Date
	}
	
	/// The latest unsent progress of each video, by slug.
	private(set) var pending: [String: Entry] = [:]
	
	private let api: API
	private let logger = Logger(category: "ProgressSync")
	private let fileURL = URL.applicationSupportDirectory
		.appending(path: Bundle.main.bundleIdentifier ?? "de.melgu.NebulaSwift", directoryHint: .isDirectory)
		.appending(path: "PendingProgress.json")
	
	/// Sends one update after the other, so an older one never overtakes a newer one.
	private var lastSend: Task<Void, Never>?
	private var isFlushing = false
	private let pathMonitor = NWPathMonitor()
	private var activationTask: Task<Void, Never>?
	
	init(api: API) {
		self.api = api
		load()
		
		pathMonitor.pathUpdateHandler = { [weak self] path in
			guard path.status == .satisfied else { return }
			Task { @MainActor in
				await self?.flush()
			}
		}
		// Also reports the current state right away, which covers the app's launch
		pathMonitor.start(queue: .main)
		
		activationTask = Task { [weak self] in
			#if canImport(UIKit)
			let notifications = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification).values
			#else
			let notifications = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification).values
			#endif
			for await _ in notifications {
				await self?.flush()
			}
		}
	}
	
	@MainActor
	deinit {
		pathMonitor.cancel()
		activationTask?.cancel()
	}
	
	/// Saves the progress, then sends it.
	func submit(_ state: Player.WatchState, seconds: Int, for video: Video) async {
		let entry = Entry(video: video, state: state, seconds: seconds, recordedAt: .now)
		pending[video.slug] = entry
		save()
		await send(entry)
	}
	
	/// Where to continue the video, if there's progress the server doesn't have yet.
	func resumePosition(for video: Video) -> Int? {
		pending[video.slug]?.seconds
	}
	
	/// The video with its unsent progress, to show it before the server has it.
	func applying(to video: Video) -> Video {
		guard let entry = pending[video.slug] else { return video }
		var video = video
		video.engagement = Video.Engagement(
			contentSlug: video.slug,
			updatedAt: entry.recordedAt,
			progress: entry.state == .unwatched ? 0 : entry.seconds,
			completed: entry.state == .watched,
			watchLater: video.engagement?.watchLater ?? false
		)
		return video
	}
	
	/// Sends the progress that couldn't be sent before, unless the server got newer progress meanwhile, like from another device.
	func flush() async {
		guard !isFlushing, !pending.isEmpty else { return }
		isFlushing = true
		defer { isFlushing = false }
		
		let entries = pending.values.sorted { $0.recordedAt < $1.recordedAt }
		let current: [Video]
		do {
			current = try await api.withEngagement(entries.map(\.video))
		} catch {
			logger.debug("Still offline: \(error)")
			return
		}
		logger.log("Send \(entries.count) progress updates made offline")
		for entry in entries {
			let serverUpdate = current.first { $0.slug == entry.video.slug }?.engagement?.updatedAt
			if let serverUpdate, serverUpdate > entry.recordedAt {
				logger.log("Server has newer progress for \(entry.video.title)")
				forget(entry)
			} else {
				await send(entry)
			}
		}
	}
	
	private func send(_ entry: Entry) async {
		let previous = lastSend
		let task = Task {
			await previous?.value
			await deliver(entry)
		}
		lastSend = task
		await task.value
	}
	
	private func deliver(_ entry: Entry) async {
		// A newer update for the video replaced this one
		guard pending[entry.video.slug] == entry else { return }
		let video = entry.video
		do {
			switch entry.state {
			case .unwatched:
				logger.log("Clear progress. \(video.title), progress: \(entry.seconds) s")
				try await api.clearProgress(for: video)
			case .inProgress:
				logger.log("Send progress. \(video.title), progress: \(entry.seconds) s")
				try await api.sendProgress(for: video, seconds: entry.seconds)
			case .watched:
				logger.log("Mark as watched. \(video.title), progress: \(entry.seconds) s")
				try await api.markVideoAsWatched(video)
			}
			forget(entry)
		} catch {
			logger.error("Sending progress failed, keeping it for later: \(error)")
		}
	}
	
	private func forget(_ entry: Entry) {
		guard pending[entry.video.slug] == entry else { return }
		pending[entry.video.slug] = nil
		save()
	}
	
	private func load() {
		do {
			pending = try JSONDecoder().decode([String: Entry].self, from: Data(contentsOf: fileURL))
		} catch CocoaError.fileReadNoSuchFile {
			// Nothing pending
		} catch {
			logger.error("Loading pending progress failed: \(error)")
		}
	}
	
	private func save() {
		do {
			try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
			try JSONEncoder().encode(pending).write(to: fileURL, options: .atomic)
		} catch {
			logger.error("Saving pending progress failed: \(error)")
		}
	}
}
