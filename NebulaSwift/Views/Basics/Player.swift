//
//  Player.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 04.04.22.
//

import SwiftUI
import AVKit
import OSLog

@MainActor @Observable
class Player {
	let player = AVPlayer()
	
	private let api: API
	private let storage: Storage

	/// Only the Picture in Picture controller renders into this layer, but it has to be in a window for Picture in Picture to start.
	let pictureInPictureLayer: AVPlayerLayer
	private let pipController: AVPictureInPictureController?

	private var video: Video?
	private var task: Task<(), Error>?
	private var rateObservationTask: Task<(), Never>?
	private var endObservationTask: Task<(), Never>?
	private var lastUpdate: Task<(), Never>?
	/// Whether the player has seeked to the video's saved progress, so its position is worth reporting.
	private var isAtSavedProgress = false
	/// Whether a preview with sound paused the video, so it resumes once the preview ends.
	private var isPausedForPreview = false

	/// The latest video removed from Watch Later because it played to the end.
	private(set) var watchLaterRemoval: WatchLaterRemoval?

	private let logger = Logger(category: "Player")
	
	private let pipDelegate = PiPDelegate()

	/// Whether the video plays in Picture in Picture, started with ``startPiP()``.
	private(set) var isPictureInPictureActive = false
	/// The latest request from Picture in Picture to show the video page again.
	private(set) var pictureInPictureRestore: PictureInPictureRestore?
	private var restoreCompletion: ((Bool) -> Void)?
	/// Whether Picture in Picture waits for the video page to show again.
	var isRestoringFromPictureInPicture: Bool {
		restoreCompletion != nil
	}
	
	init(api: API, storage: Storage) {
		self.api = api
		self.storage = storage

		pictureInPictureLayer = AVPlayerLayer(player: player)
		pipController = AVPictureInPictureController(playerLayer: pictureInPictureLayer)
		pipController?.delegate = pipDelegate
		
		#if canImport(UIKit)
		Self.configurePlaybackSession()
		// The player view controller starts Picture in Picture on its own when leaving the app
		pipController?.canStartPictureInPictureAutomaticallyFromInline = false
		#endif
		
		player.preventsDisplaySleepDuringVideoPlayback = true
		
		pipDelegate.player = self
		
		rateObservationTask = Task { [weak self, player] in
			for await rate in player.publisher(for: \.rate).values {
				guard let self else { return }
				if rate.isZero {
					sendProgress()
				} else {
					didStartPlaying()
				}
			}
		}

		endObservationTask = Task { [weak self, player] in
			for await item in NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification).map({ $0.object as? AVPlayerItem }).values {
				guard let self else { return }
				if let item, item === player.currentItem {
					didPlayToEnd()
				}
			}
		}
	}

	@MainActor
	deinit {
		rateObservationTask?.cancel()
		endObservationTask?.cancel()
	}
	
	func play() {
		logger.debug("Play")
		#if canImport(UIKit)
		// A muted preview may have left the session mixable
		Self.configurePlaybackSession()
		try? AVAudioSession.sharedInstance().setActive(true)
		#endif
		player.play()
	}
	
	func pause() {
		logger.debug("Pause")
		player.pause()
		#if canImport(UIKit)
		try? AVAudioSession.sharedInstance().setActive(false)
		#endif
	}
	
	/// Lets a muted preview play without interrupting other apps' audio, and pauses the video for a preview with sound.
	func beginPreview(muted: Bool) {
		#if canImport(UIKit)
		if muted {
			// Leave the session alone while the main player owns it
			guard player.rate.isZero else { return }
			try? AVAudioSession.sharedInstance().setCategory(.ambient)
		} else if !player.rate.isZero {
			logger.debug("Pause for preview with sound")
			// The preview takes over the session, so it stays active
			player.pause()
			isPausedForPreview = true
		}
		#endif
	}

	/// Resumes the video a preview paused, or else hands the audio back to other apps.
	func endPreview(muted: Bool) {
		#if canImport(UIKit)
		if isPausedForPreview {
			isPausedForPreview = false
			logger.debug("Resume after preview")
			play()
			return
		}
		guard player.rate.isZero else { return }
		// Deactivate first, so switching back to a non-mixable category doesn't interrupt other audio
		do {
			try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
			logger.debug("Deactivated session after preview")
		} catch {
			logger.error("Deactivating session after preview failed: \(error)")
		}
		if muted {
			Self.configurePlaybackSession()
		}
		#endif
	}

	/// Picture in Picture plays the video without ``play()``, so this also covers a session a muted preview left mixable.
	private func didStartPlaying() {
		isPausedForPreview = false
		#if canImport(UIKit)
		let session = AVAudioSession.sharedInstance()
		guard session.category != .playback else { return }
		logger.debug("Restore playback session")
		Self.configurePlaybackSession()
		try? session.setActive(true)
		#endif
	}

	#if canImport(UIKit)
	private static func configurePlaybackSession() {
		try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
	}
	#endif
	
	func startPiP() {
		logger.debug("Possible: \(String(describing: self.pipController?.isPictureInPicturePossible)), active: \(String(describing: self.pipController?.isPictureInPictureActive)), suspended: \(String(describing: self.pipController?.isPictureInPictureSuspended))")
		#if canImport(UIKit)
		logger.debug("Activation state is: \(String(describing: UIApplication.shared.connectedScenes.first?.activationState))")
		#endif
		pipController?.startPictureInPicture()
	}
	
	func stopPiP() {
		pipController?.stopPictureInPicture()
	}
	
	/// Lets Picture in Picture hand the video back, once its page is on screen again.
	func completePictureInPictureRestore() {
		guard let restoreCompletion else { return }
		logger.debug("PiP restore completed")
		self.restoreCompletion = nil
		restoreCompletion(true)
	}
	
	fileprivate func pictureInPictureDidStart() {
		isPictureInPictureActive = true
	}
	
	fileprivate func pictureInPictureDidStop() {
		isPictureInPictureActive = false
		// In case nothing showed the video page in time
		completePictureInPictureRestore()
	}
	
	fileprivate func restoreFromPictureInPicture(completion: @escaping (Bool) -> Void) {
		guard let video else {
			completion(false)
			return
		}
		restoreCompletion?(false)
		restoreCompletion = completion
		pictureInPictureRestore = PictureInPictureRestore(video: video)
	}
	
	func replaceVideo(with video: Video) async throws {
		guard video.slug != self.video?.slug else {
			logger.debug("Replacement video is the same. So no action is taken.")
			return
		}
		logger.debug("Replace video \(self.video?.title ?? "nil") with \(video.title)")
		task?.cancel()
		
		sendProgress()
		
		self.video = video
		isAtSavedProgress = false
		isPausedForPreview = false

		task = Task {
						let item = AVPlayerItem(url: try api.manifestURL(for: video))
			try Task.checkCancellation()
			player.replaceCurrentItem(with: item)
			if let progress = video.engagement?.progress {
				logger.debug("Seeking to progress \(progress)")
				await player.seek(to: CMTime(seconds: Double(progress), preferredTimescale: 1))
			}
			try Task.checkCancellation()
			isAtSavedProgress = true
		}
		try await task?.value
	}
	
	func reset() {
		logger.debug("Reset")
		sendProgress()
		task?.cancel()
		video = nil
		isAtSavedProgress = false
		isPausedForPreview = false
		player.replaceCurrentItem(with: nil)
		#if canImport(UIKit)
		try? AVAudioSession.sharedInstance().setActive(false)
		#endif
	}
	
	/// Waits until the server has received every update the player sent so far, like progress or Watch Later changes.
	func waitForPendingUpdates() async {
		await lastUpdate?.value
	}

	private func didPlayToEnd() {
		// The video's engagement is from when it was opened, so it may not know about later Watch Later changes.
		guard storage.removeFromWatchLaterAfterPlayback, let video = video else { return }
		logger.log("Remove \(video.title) from Watch Later after playback")
		enqueueUpdate { [api] in
			try await api.removeVideoFromWatchLater(video)
			self.watchLaterRemoval = WatchLaterRemoval(slug: video.slug)
		}
	}

	private func sendProgress() {
		// Before the seek, the position is 0 and would clear the saved progress
		guard let video = video, player.currentItem != nil, isAtSavedProgress else { return }
		let seconds = Int(player.currentTime().seconds)
		switch WatchState(seconds: seconds, duration: video.duration) {
		case .unwatched:
			logger.log("Clear progress. \(video.title), progress: \(seconds) s")
			enqueueUpdate { [api] in
				try await api.clearProgress(for: video)
			}
		case .inProgress:
			logger.log("Send progress. \(video.title), progress: \(seconds) s")
			enqueueUpdate { [api] in
				try await api.sendProgress(for: video, seconds: seconds)
			}
		case .watched:
			logger.log("Mark as watched. \(video.title), progress: \(seconds) s")
			enqueueUpdate { [api] in
				try await api.markVideoAsWatched(video)
			}
		}
	}

	/// Sends updates one after the other, so ``waitForPendingUpdates()`` only has to wait for the last one.
	private func enqueueUpdate(_ update: @escaping @MainActor () async throws -> Void) {
		let previous = lastUpdate
		lastUpdate = Task.finishingInBackground(named: "Player update") {
			await previous?.value
			do {
				try await update()
			} catch {
				logger.error("Update failed: \(error)")
			}
		}
	}
}

extension Player {
	/// What to report for a video stopped at a given position.
	enum WatchState: Equatable {
		case unwatched
		case inProgress
		case watched

		/// How close to the start or end a position counts as unwatched or watched.
		static let margin = 10

		init(seconds: Int, duration: Int) {
			if duration < 2 * Self.margin {
				// The margins would overlap, so the closer end wins
				self = seconds * 2 < duration ? .unwatched : .watched
			} else if seconds < Self.margin {
				self = .unwatched
			} else if duration - seconds < Self.margin {
				self = .watched
			} else {
				self = .inProgress
			}
		}
	}

	/// A video removed from Watch Later because it played to the end.
	struct WatchLaterRemoval: Equatable {
		let slug: String
		/// Tells apart removals of the same video, in case it was added back and played again.
		private let id = UUID()

		init(slug: String) {
			self.slug = slug
		}
	}
	
	/// A request from Picture in Picture to show the video page again.
	struct PictureInPictureRestore: Equatable {
		let video: Video
		/// Tells apart requests for the same video.
		private let id = UUID()
		
		init(video: Video) {
			self.video = video
		}
		
		static func == (lhs: Self, rhs: Self) -> Bool {
			lhs.id == rhs.id
		}
	}
}

@MainActor
private class PiPDelegate: NSObject, @preconcurrency AVPictureInPictureControllerDelegate {
	private let logger = Logger(category: "PiPDelegate")

	weak var player: Player?

	func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
		logger.debug("PiP didStart")
		player?.pictureInPictureDidStart()
	}

	func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
		logger.debug("PiP didStop")
		player?.pictureInPictureDidStop()
	}
	
	func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
		// We do not support audio through the pipify controller, as such we will allow other background audio to
		// continue playing
		return false
	}
	
	func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
		logger.debug("PiP failed to start: \(error)")
	}
	
	func pictureInPictureController(
		_ pictureInPictureController: AVPictureInPictureController,
		restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
	) {
		logger.debug("PiP restore UI")
		if let player {
			player.restoreFromPictureInPicture(completion: completionHandler)
		} else {
			completionHandler(false)
		}
	}
}

#if canImport(UIKit)
extension UIScene.ActivationState: @retroactive CustomStringConvertible {
	public var description: String {
		switch self {
		case .unattached:
			return "unattached"
		case .foregroundActive:
			return "foregroundActive"
		case .foregroundInactive:
			return "foregroundInactive"
		case .background:
			return "background"
		@unknown default:
			return "unknown state: \(rawValue)"
		}
	}
}
#endif
