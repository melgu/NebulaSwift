//
//  NebulaSwiftApp.swift
//  Shared
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

@main
struct NebulaSwiftApp: App {
	@StateObject var api: API
	
	init() {
		_api = StateObject(wrappedValue: API())
	}
	
    var body: some Scene {
        WindowGroup {
			if api.isLoggedIn {
				ContentView()
					.environmentObject(api)
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
