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
	var startPage: StartPage {
		didSet { UserDefaults.standard.set(startPage.rawValue, forKey: Defaults.startPage) }
	}
	var downloadQuality: DownloadQuality {
		didSet { UserDefaults.standard.set(downloadQuality.rawValue, forKey: Defaults.downloadQuality) }
	}

	init() {
		let defaults = UserDefaults.standard
		
		automaticFullscreen = defaults.bool(forKey: Defaults.automaticFullscreen)
		videoPreview = defaults.optionalBool(forKey: Defaults.videoPreview) ?? true
		videoPreviewWithSound = defaults.optionalBool(forKey: Defaults.videoPreviewWithSound) ?? true
		removeFromWatchLaterAfterPlayback = defaults.bool(forKey: Defaults.removeFromWatchLaterAfterPlayback)
		previewTitleLines = defaults.optionalInt(forKey: Defaults.previewTitleLines) ?? 2
		startPage = .saved
		downloadQuality = defaults.optionalInt(forKey: Defaults.downloadQuality).flatMap(DownloadQuality.init(rawValue:)) ?? .best
	}
}

/// The highest resolution to download videos in.
enum DownloadQuality: Int, CaseIterable, Identifiable {
	case best = 0
	case p2160 = 2160
	case p1440 = 1440
	case p1080 = 1080
	case p720 = 720
	case p540 = 540
	case p360 = 360
	
	var id: Self { self }
	
	/// `nil` for the best quality.
	var maxHeight: Int? {
		self == .best ? nil : rawValue
	}
	
	var title: LocalizedStringKey {
		switch self {
		case .best: "Best"
		case .p2160: "2160p (4K)"
		default: "\(rawValue)p"
		}
	}
}

/// The page the app opens on.
enum StartPage: String, CaseIterable, Identifiable {
	case featured, myShows, browse, watchLater, downloads

	var id: Self { self }

	/// Readable before `Storage` is in the environment, so the first frame already shows the page.
	static var saved: StartPage {
		UserDefaults.standard.string(forKey: Defaults.startPage).flatMap(StartPage.init(rawValue:)) ?? .myShows
	}

	var title: LocalizedStringKey {
		switch self {
		case .featured: "Featured"
		case .myShows: "My Shows"
		case .browse: "Browse"
		case .watchLater: "Watch Later"
		case .downloads: "Downloads"
		}
	}

	var systemImage: String {
		switch self {
		case .featured: "star.circle"
		case .myShows: "suit.heart"
		case .browse: "list.dash"
		case .watchLater: "bookmark"
		case .downloads: "arrow.down.circle"
		}
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
