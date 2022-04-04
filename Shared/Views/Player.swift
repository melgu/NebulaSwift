//
//  Player.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 04.04.22.
//

import SwiftUI
import AVKit

private struct Player: EnvironmentKey {
	static let defaultValue = AVPlayer()
}

extension EnvironmentValues {
	var player: AVPlayer {
		get { self[Player.self] }
		set { self[Player.self] = newValue }
	}
}
