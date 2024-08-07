//
//  Player.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 04.04.22.
//

import SwiftUI
import Combine
import AVKit
import OSLog

@MainActor class Player: ObservableObject {
	let player = AVPlayer()
	
	private let api: API
	
	private let pipController: AVPictureInPictureController?
	
	private var video: Video?
	private var task: Task<(), Error>?
	private var cancellables = Set<AnyCancellable>()
	
	private let logger = Logger(category: "Player")
	
	private let pipDelegate = PiPDelegate()
	
	init(api: API) {
		self.api = api
		
		let layer = AVPlayerLayer(player: player)
		pipController = AVPictureInPictureController(playerLayer: layer)
		pipController?.delegate = pipDelegate
		
		#if canImport(UIKit)
		try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
		pipController?.canStartPictureInPictureAutomaticallyFromInline = true
		#endif
		
		player.preventsDisplaySleepDuringVideoPlayback = true
		
		player.publisher(for: \.rate)
			.sink { [unowned self] rate in
				if rate.isZero {
					sendProgress()
				}
			}
			.store(in: &cancellables)
	}
	
	func play() {
		logger.debug("Play")
		#if canImport(UIKit)
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
			let stream = try await api.stream(for: video)
			let item = AVPlayerItem(url: stream.manifest)
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
