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

	private let pipController: AVPictureInPictureController?

	private var video: Video?
	private var task: Task<(), Error>?
	private var rateObservationTask: Task<(), Never>?
	private var endObservationTask: Task<(), Never>?
	
	private let logger = Logger(category: "Player")
	
	private let pipDelegate = PiPDelegate()
	
	init(api: API, storage: Storage) {
		self.api = api
		self.storage = storage

		let layer = AVPlayerLayer(player: player)
		pipController = AVPictureInPictureController(playerLayer: layer)
		pipController?.delegate = pipDelegate
		
		#if canImport(UIKit)
		Self.configurePlaybackSession()
		pipController?.canStartPictureInPictureAutomaticallyFromInline = true
		#endif
		
		player.preventsDisplaySleepDuringVideoPlayback = true
		
		rateObservationTask = Task { [weak self, player] in
			for await rate in player.publisher(for: \.rate).values {
				guard let self else { return }
				if rate.isZero {
					sendProgress()
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
	
	/// Lets a muted preview play without interrupting other apps' audio.
	func beginMutedPreview() {
		#if canImport(UIKit)
		// Leave the session alone while the main player owns it
		guard player.rate.isZero else { return }
		try? AVAudioSession.sharedInstance().setCategory(.ambient)
		#endif
	}
	
	func endMutedPreview() {
		#if canImport(UIKit)
		guard player.rate.isZero else { return }
		// Deactivate first, so switching back to a non-mixable category doesn't interrupt other audio
		try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
		Self.configurePlaybackSession()
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
	
	func replaceVideo(with video: Video) async throws {
		guard video.slug != self.video?.slug else {
			logger.debug("Replacement video is the same. So no action is taken.")
			return
		}
		logger.debug("Replace video \(self.video?.title ?? "nil") with \(video.title)")
		task?.cancel()
		
		sendProgress()
		
		self.video = video
		
		task = Task {
						let item = AVPlayerItem(url: try api.manifestURL(for: video))
			try Task.checkCancellation()
			player.replaceCurrentItem(with: item)
			if let progress = video.engagement?.progress {
				logger.debug("Seeking to progress \(progress)")
				await player.seek(to: CMTime(seconds: Double(progress), preferredTimescale: 1))
			}
		}
		try await task?.value
	}
	
	func reset() {
		logger.debug("Reset")
		sendProgress()
		task?.cancel()
		video = nil
		player.replaceCurrentItem(with: nil)
		#if canImport(UIKit)
		try? AVAudioSession.sharedInstance().setActive(false)
		#endif
	}
	
	private func didPlayToEnd() {
		guard storage.removeFromWatchLaterAfterPlayback,
			  let video = video,
			  video.engagement?.watchLater != false
		else { return }
		logger.log("Remove \(video.title) from Watch Later after playback")
		Task {
			try await api.removeVideoFromWatchLater(video)
		}
	}

	private func sendProgress() {
		guard let video = video, player.currentItem != nil else { return }
		let seconds = Int(player.currentTime().seconds)
		logger.log("Send progress. \(video.title), progress: \(seconds) s")
		Task {
			try await api.sendProgress(for: video, seconds: seconds)
		}
	}
}

private class PiPDelegate: NSObject, AVPictureInPictureControllerDelegate {
	private let logger = Logger(category: "PiPDelegate")
	
	func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
		logger.debug("PiP didStart")
	}
	
	func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
		logger.debug("PiP didStop")
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
