//
//  NebulaSwiftApp.swift
//  Shared
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

@main
struct NebulaSwiftApp: App {
	@State private var api: API
	@State private var player: Player
	@State private var storage = Storage()
	
	init() {
		let api = API()
		self.api = api
		self.player = Player(api: api)
	}
	
	var body: some Scene {
		WindowGroup {
			ContentView()
				.environment(api)
				.environment(player)
				.environment(storage)
				.task { try await api.refreshConfiguration() }
		}
		.commands {
			CommandMenu("Account") {
				Button("Logout") {
					api.logout()
				}
			}
		}
		
		#if os(macOS)
		Settings {
			SettingsView()
				.environment(api)
				.environment(player)
				.environment(storage)
		}
		#endif
	}
}
