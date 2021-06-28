//
//  Settings.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

class Settings: ObservableObject {
	static let shared = Settings()
	
	@AppStorage(Defaults.token) var token = ""
	@AppStorage(Defaults.bearer) var bearer = ""
	@AppStorage(Defaults.nebulaAuthApi) var nebulaAuthApi = ""
	@AppStorage(Defaults.nebulaContentApi) var nebulaContentApi = ""
	@AppStorage(Defaults.zypeApi) var zypeApi = ""
	
	let zypeAuthInfo = ZypeAuthInfo()
	
	private init() {}
}

extension Settings {
	class ZypeAuthInfo: ObservableObject {
		@AppStorage(Defaults.ZypeAuthInfo.accessToken) var accessToken = ""
		@AppStorage(Defaults.ZypeAuthInfo.expiresAt) var expiresAt = -1
		@AppStorage(Defaults.ZypeAuthInfo.refreshToken) var refreshToken = ""
	}
}

extension Settings {
	func clearAll() {
		token = ""
		bearer = ""
		nebulaAuthApi = ""
		nebulaContentApi = ""
		zypeApi = ""
		zypeAuthInfo.accessToken = ""
		zypeAuthInfo.expiresAt = -1
		zypeAuthInfo.refreshToken = ""
	}
}
