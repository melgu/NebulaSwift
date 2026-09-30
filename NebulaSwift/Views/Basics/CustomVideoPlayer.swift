//
//  CustomVideoPlayer.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import SwiftUI
import AVKit
import OSLog

#if canImport(UIKit)
struct CustomVideoPlayer: UIViewControllerRepresentable {
	@Environment(Player.self) private var player
	@Environment(Storage.self) private var storage
	
	func makeUIViewController(context: Context) -> AVPlayerViewController {
		let playerViewController = AVPlayerViewController()
		playerViewController.player = player.player
		playerViewController.entersFullScreenWhenPlaybackBegins = storage.automaticFullscreen
		playerViewController.exitsFullScreenWhenPlaybackEnds = true
		playerViewController.canStartPictureInPictureAutomaticallyFromInline = true
		// Picture in Picture hands the video back to the inline player, so going fullscreen afterwards would flicker
		if storage.automaticFullscreen && !player.isRestoringFromPictureInPicture {
			playerViewController.goFullScreen()
		}
		return playerViewController
	}

	func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

/// Puts the Picture in Picture layer into the window, since Picture in Picture can't start otherwise.
///
/// Meant to sit behind ``CustomVideoPlayer``, so it isn't seen.
struct PictureInPictureSource: UIViewRepresentable {
	@Environment(Player.self) private var player

	func makeUIView(context: Context) -> some UIView {
		PlayerLayerView(playerLayer: player.pictureInPictureLayer)
	}

	func updateUIView(_ uiView: UIViewType, context: Context) {}
}

/// Hosts a player layer that may move on to a newer player page.
private class PlayerLayerView: UIView {
	private let playerLayer: AVPlayerLayer

	init(playerLayer: AVPlayerLayer) {
		self.playerLayer = playerLayer
		super.init(frame: .zero)
		layer.addSublayer(playerLayer)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		guard playerLayer.superlayer === layer else { return }
		playerLayer.frame = bounds
	}
}

private let logger = Logger(category: "AVPlayerViewController")

extension AVPlayerViewController {
	// TODO: Does this prevent me from getting into the app store?
	func goFullScreen() {
		let selectorName = "_transitionToFullScreenAnimated:interactive:completionHandler:"
		let selectorToForceFullScreenMode = NSSelectorFromString(selectorName)
		
		if responds(to: selectorToForceFullScreenMode) {
			perform(selectorToForceFullScreenMode, with: true, with: nil)
		} else {
			logger.error("Go to fullscreen selector doesn't work")
		}
	}
}
#else
struct CustomVideoPlayer: NSViewRepresentable {
	@Environment(Player.self) private var player
	
	func makeNSView(context: Context) -> AVPlayerView {
		let playerView = AVPlayerView()
		playerView.player = player.player
		playerView.showsFullScreenToggleButton = true
		playerView.allowsPictureInPicturePlayback = true
		return playerView
	}
	
	func updateNSView(_ nsView: NSViewType, context: Context) {}
}
#endif

struct CustomVideoPlayer_Previews: PreviewProvider {
	static var previews: some View {
		CustomVideoPlayer()
			.environment(Player(api: API(), storage: Storage()))
	}
}
