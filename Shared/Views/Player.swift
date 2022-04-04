//
//  Player.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 04.04.22.
//

import SwiftUI
import AVKit

@MainActor class Player: ObservableObject {
	let player = AVPlayer()
	
	private let api: API
	
	private var video: Video?
	private var task: Task<(), Error>?
	
	init(api: API) {
		self.api = api
	}
	
	func play() {
		player.play()
	}
	
	func pause() {
		sendProgress()
		player.pause()
	}
	
	func replaceVideo(with video: Video) async throws {
		task?.cancel()
		
		sendProgress()
		
		self.video = video
		
		task = Task {
			let stream = try await api.stream(for: video)
			let item = AVPlayerItem(url: stream.manifest)
			try Task.checkCancellation()
			player.replaceCurrentItem(with: item)
			print("Player: Seeking to progress \(video.engagement.progress)")
			await player.seek(to: CMTime(seconds: Double(video.engagement.progress), preferredTimescale: 1))
		}
		try await task?.value
	}
	
	func reset() {
		sendProgress()
		task?.cancel()
		video = nil
		player.replaceCurrentItem(with: nil)
	}
	
	private func sendProgress() {
		guard let video = video, player.currentItem != nil else { return }
		let seconds = Int(player.currentTime().seconds)
		Task {
			try await api.sendProgress(for: video, seconds: seconds)
		}
	}
}
