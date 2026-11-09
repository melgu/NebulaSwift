//
//  NebulaSwiftApp.swift
//  Shared
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

@main
struct NebulaSwiftApp: App {
	#if os(macOS)
	/// In the environment, since it's `Observable`.
	@NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
	#else
	/// Sets up the scene delegate for the quick actions.
	@UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
	#endif

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
		// Without an id, the saved window frame is keyed by the content's type, whose name changes with every launch
		WindowGroup(id: "main") {
			ContentView()
				// Outside of ContentView, so it can report its own errors through handleError
				.alertErrorHandling()
				.environment(api)
				.environment(player)
				.environment(storage)
				.environment(downloads)
				.task { try await api.refreshConfiguration() }
				#if os(iOS)
				.onAppear { storage.applyQuickActions() }
				#endif
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
