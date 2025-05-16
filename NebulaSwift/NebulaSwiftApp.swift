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
	@StateObject private var player: Player
	@StateObject private var storage = Storage()
	
	init() {
		let api = API()
		_api = StateObject(wrappedValue: api)
		let player = Player(api: api)
		_player = StateObject(wrappedValue: player)
	}
	
	var body: some Scene {
		WindowGroup {
			ContentView()
				.environmentObject(api)
				.environmentObject(player)
				.environmentObject(storage)
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
				.environmentObject(player)
				.environmentObject(storage)
		}
		#endif
	}
}
