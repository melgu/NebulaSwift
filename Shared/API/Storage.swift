//
//  Settings.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI
import Combine

@MainActor class Storage: ObservableObject {
	@Published var token: String?
	@Published var bearer: String?
	@Published var nebulaAuthApi: String?
	@Published var nebulaContentApi: String?
	@Published var zypeApi: String?
	
	@Published var automaticFullscreen: Bool
	
	let zypeAuthInfo = ZypeAuthInfo()
	
	private var cancellables = Set<AnyCancellable>()
	
	init() {
		let defaults = UserDefaults.standard
		token = defaults.string(forKey: Defaults.token)
		bearer = defaults.string(forKey: Defaults.bearer)
		nebulaAuthApi = defaults.string(forKey: Defaults.nebulaAuthApi)
		nebulaContentApi = defaults.string(forKey: Defaults.nebulaContentApi)
		zypeApi = defaults.string(forKey: Defaults.zypeApi)
		
		automaticFullscreen = defaults.bool(forKey: Defaults.automaticFullscreen)
		
		$token
			.dropFirst()
			.sink { defaults.set($0, forKey: Defaults.token) }
			.store(in: &cancellables)
		$bearer
			.dropFirst()
			.sink { defaults.set($0, forKey: Defaults.bearer) }
			.store(in: &cancellables)
		$nebulaAuthApi
			.dropFirst()
			.sink { defaults.set($0, forKey: Defaults.nebulaAuthApi) }
			.store(in: &cancellables)
		$nebulaContentApi
			.dropFirst()
			.sink { defaults.set($0, forKey: Defaults.nebulaContentApi) }
			.store(in: &cancellables)
		$zypeApi
			.dropFirst()
			.sink { defaults.set($0, forKey: Defaults.zypeApi) }
			.store(in: &cancellables)
		
		$automaticFullscreen
			.dropFirst()
			.sink { defaults.set($0, forKey: Defaults.automaticFullscreen) }
			.store(in: &cancellables)
	}
}

extension Storage {
	@MainActor class ZypeAuthInfo {
		@Published var accessToken: String?
		@Published var expiresAt: Int?
		@Published var refreshToken: String?
		
		private var cancellables = Set<AnyCancellable>()
		
		fileprivate init() {
			let defaults = UserDefaults.standard
			accessToken = defaults.string(forKey: Defaults.ZypeAuthInfo.accessToken)
			expiresAt = defaults.integer(forKey: Defaults.ZypeAuthInfo.expiresAt)
			refreshToken = defaults.string(forKey: Defaults.ZypeAuthInfo.refreshToken)
			
			$accessToken
				.dropFirst()
				.sink { defaults.set($0, forKey: Defaults.ZypeAuthInfo.accessToken) }
				.store(in: &cancellables)
			$expiresAt
				.dropFirst()
				.sink { defaults.set($0, forKey: Defaults.ZypeAuthInfo.expiresAt) }
				.store(in: &cancellables)
			$refreshToken
				.dropFirst()
				.sink { defaults.set($0, forKey: Defaults.ZypeAuthInfo.refreshToken) }
				.store(in: &cancellables)
		}
	}
}
