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
	
	@Published var automaticFullscreen: Bool
	@Published var videoPreview: Bool
	@Published var videoPreviewWithSound: Bool
	
	private var cancellables = Set<AnyCancellable>()
	
	init() {
		let defaults = UserDefaults.standard
		token = defaults.string(forKey: Defaults.token)
		bearer = defaults.string(forKey: Defaults.bearer)
		nebulaAuthApi = defaults.string(forKey: Defaults.nebulaAuthApi)
		nebulaContentApi = defaults.string(forKey: Defaults.nebulaContentApi)
		
		automaticFullscreen = defaults.bool(forKey: Defaults.automaticFullscreen)
		videoPreview = defaults.optionalBool(forKey: Defaults.videoPreview) ?? true
		videoPreviewWithSound = defaults.optionalBool(forKey: Defaults.videoPreviewWithSound) ?? true
		
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
		
		$automaticFullscreen
			.dropFirst()
			.sink { defaults.set($0, forKey: Defaults.automaticFullscreen) }
			.store(in: &cancellables)
		
		$videoPreview
			.dropFirst()
			.sink { defaults.set($0, forKey: Defaults.videoPreview) }
			.store(in: &cancellables)
		
		$videoPreviewWithSound
			.dropFirst()
			.sink { defaults.set($0, forKey: Defaults.videoPreviewWithSound) }
			.store(in: &cancellables)
	}
}

private extension UserDefaults {
	func optionalBool(forKey defaultName: String) -> Bool? {
		guard object(forKey: defaultName) != nil else { return nil }
		return bool(forKey: defaultName)
	}
}
