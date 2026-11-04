//
//  Defaults.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import Foundation

enum Defaults {}

extension Defaults {
	/// Also the Keychain account. Older versions kept the login in UserDefaults under this key.
	static let token = "token"
	/// Also the Keychain account. Older versions kept the authorization in UserDefaults under this key.
	static let bearer = "bearer"
	static let authBaseURL = "authBaseURL"
	static let contentBaseURL = "contentBaseURL"
	
	static let automaticFullscreen = "automaticFullscreen"
	static let videoPreview = "videoPreview"
	static let videoPreviewWithSound = "videoPreviewWithSound"
	static let removeFromWatchLaterAfterPlayback = "removeFromWatchLaterAfterPlayback"
	static let closeVideoAfterPlayback = "closeVideoAfterPlayback"
	static let previewTitleLines = "previewTitleLines"
	static let startPage = "startPage"
	static let downloadQuality = "downloadQuality"
	static let quickActions = "quickActions"
}
