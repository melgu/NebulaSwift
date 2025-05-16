//
//  Settings.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI
import Combine

@MainActor class Storage: ObservableObject {
	@Published var automaticFullscreen: Bool
	@Published var videoPreview: Bool
	@Published var videoPreviewWithSound: Bool
	
	private var cancellables = Set<AnyCancellable>()
	
	init() {
		let defaults = UserDefaults.standard
		
		automaticFullscreen = defaults.bool(forKey: Defaults.automaticFullscreen)
		videoPreview = defaults.optionalBool(forKey: Defaults.videoPreview) ?? true
		videoPreviewWithSound = defaults.optionalBool(forKey: Defaults.videoPreviewWithSound) ?? true
		
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
