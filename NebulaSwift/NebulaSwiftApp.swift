//
//  NebulaSwiftApp.swift
//  Shared
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

@main
struct NebulaSwiftApp: App {
	@StateObject private var api: API
	@State private var player: Player
	@State private var storage = Storage()
	
	init() {
		let api = API()
		_api = StateObject(wrappedValue: api)
		let player = Player(api: api)
		_player = State(initialValue: player)
	}
	
	var body: some Scene {
		WindowGroup {
			ContentView()
				.environmentObject(api)
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
				.environmentObject(api)
				.environment(player)
				.environment(storage)
		}
		#endif
	}
}
