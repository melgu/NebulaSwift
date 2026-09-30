//
//  Settings.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

@MainActor @Observable
class Storage {
	var automaticFullscreen: Bool {
		didSet { UserDefaults.standard.set(automaticFullscreen, forKey: Defaults.automaticFullscreen) }
	}
	var videoPreview: Bool {
		didSet { UserDefaults.standard.set(videoPreview, forKey: Defaults.videoPreview) }
	}
	var videoPreviewWithSound: Bool {
		didSet { UserDefaults.standard.set(videoPreviewWithSound, forKey: Defaults.videoPreviewWithSound) }
	}
	var removeFromWatchLaterAfterPlayback: Bool {
		didSet { UserDefaults.standard.set(removeFromWatchLaterAfterPlayback, forKey: Defaults.removeFromWatchLaterAfterPlayback) }
	}
	var previewTitleLines: Int {
		didSet { UserDefaults.standard.set(previewTitleLines, forKey: Defaults.previewTitleLines) }
	}

	init() {
		let defaults = UserDefaults.standard
		
		automaticFullscreen = defaults.bool(forKey: Defaults.automaticFullscreen)
		videoPreview = defaults.optionalBool(forKey: Defaults.videoPreview) ?? true
		videoPreviewWithSound = defaults.optionalBool(forKey: Defaults.videoPreviewWithSound) ?? true
		removeFromWatchLaterAfterPlayback = defaults.bool(forKey: Defaults.removeFromWatchLaterAfterPlayback)
		previewTitleLines = defaults.optionalInt(forKey: Defaults.previewTitleLines) ?? 2
	}
}

private extension UserDefaults {
	func optionalBool(forKey defaultName: String) -> Bool? {
		guard object(forKey: defaultName) != nil else { return nil }
		return bool(forKey: defaultName)
	}
	
	func optionalInt(forKey defaultName: String) -> Int? {
		guard object(forKey: defaultName) != nil else { return nil }
		return integer(forKey: defaultName)
	}
}
