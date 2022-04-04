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
	
	init() {
		let api = API()
		_api = StateObject(wrappedValue: api)
		let player = Player(api: api)
		_player = StateObject(wrappedValue: player)
	}
	
    var body: some Scene {
        WindowGroup {
			if api.isLoggedIn {
				ContentView()
					.environmentObject(api)
					.environmentObject(player)
			} else {
				Login()
					.environmentObject(api)
			}
        }
		.commands {
			CommandMenu("Account") {
				Button("Logout") {
					api.logout()
				}
			}
		}
		#if os(macOS)
		.windowStyle(.hiddenTitleBar)
		#endif
		
		#if os(macOS)
		Settings {
			SettingsView()
		}
		#endif
    }
}
