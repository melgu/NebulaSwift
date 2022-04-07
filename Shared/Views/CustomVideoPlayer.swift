//
//  CustomVideoPlayer.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import SwiftUI
import AVKit

#if canImport(UIKit)
struct CustomVideoPlayer: UIViewControllerRepresentable {
	@EnvironmentObject private var player: Player
	
	func makeUIViewController(context: Context) -> AVPlayerViewController {
		let playerViewController = AVPlayerViewController()
		playerViewController.player = player.player
		return playerViewController
	}
	
	func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
#else
struct CustomVideoPlayer: NSViewRepresentable {
	@EnvironmentObject private var player: Player
	
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
			.environmentObject(Player(api: API()))
    }
}
