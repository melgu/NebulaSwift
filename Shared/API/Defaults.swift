//
//  Defaults.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import Foundation

enum Defaults {}

extension Defaults {
	static let token = "token"
	static let bearer = "bearer"
	static let nebulaAuthApi = "nebulaAuthApi"
	static let nebulaContentApi = "nebulaContentApi"
	static let zypeApi = "zypeApi"
	
	static let automaticFullscreen = "automaticFullscreen"
	static let videoPreview = "videoPreview"
	
	enum ZypeAuthInfo {
		static let accessToken = "ZypeAuthInfo-accessToken"
		static let expiresAt = "ZypeAuthInfo-expiresAt"
		static let refreshToken = "ZypeAuthInfo-refreshToken"
	}
}
