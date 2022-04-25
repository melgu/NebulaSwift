//
//  Player.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 04.04.22.
//

import SwiftUI
import Combine
import AVKit
import os.log

@MainActor class Player: ObservableObject {
	let player = AVPlayer()
	
	private let api: API
	
	private let pipController: AVPictureInPictureController?
	
	private var video: Video?
	private var task: Task<(), Error>?
	private var cancellables = Set<AnyCancellable>()
	
	private let logger = Logger(category: "Player")
	
	init(api: API) {
		self.api = api
		
		let layer = AVPlayerLayer(player: player)
		pipController = AVPictureInPictureController(playerLayer: layer)
		
		#if canImport(UIKit)
		try? AVAudioSession.sharedInstance().setCategory(.playback)
		pipController?.canStartPictureInPictureAutomaticallyFromInline = true
		#endif
		
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
		try? AVAudioSession.sharedInstance().setActive(true, options: [])
		#endif
		player.play()
	}
	
	func pause() {
		logger.debug("Pause")
		#if canImport(UIKit)
		try? AVAudioSession.sharedInstance().setActive(false)
		#endif
		sendProgress()
		player.pause()
	}
	
	func replaceVideo(with video: Video) async throws {
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
