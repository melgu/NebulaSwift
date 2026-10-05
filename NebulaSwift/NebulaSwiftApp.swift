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
	@State private var storage: Storage
	@State private var downloads: DownloadManager

	init() {
		let api = API()
		let storage = Storage()
		let downloads = DownloadManager(api: api, storage: storage)
		self.api = api
		self.storage = storage
		self.downloads = downloads
		self.player = Player(api: api, storage: storage, downloads: downloads)
	}
	
	var body: some Scene {
		WindowGroup {
			ContentView()
				.environment(api)
				.environment(player)
				.environment(storage)
				.environment(downloads)
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
				.environment(downloads)
		}
		#endif
	}
}
