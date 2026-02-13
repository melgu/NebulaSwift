//
//  Settings.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 04.04.22.
//

import SwiftUI

struct SettingsView: View {
	@Environment(API.self) private var api
	@Environment(Storage.self) private var storage
	@Environment(Player.self) private var player
	
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		#if os(iOS)
		NavigationStack {
			content
				.navigationTitle("Settings")
				.navigationBarCloseButton()
		}
		#else
		content
		#endif
	}
	
	private var content: some View {
		@Bindable var storage = storage
		return List {
			#if os(iOS) // No way to automatically enter fullscreen on macOS (without crashing the OS)
			Section("Playback") {
				Toggle("Automatic Fullscreen", isOn: $storage.automaticFullscreen)
				Toggle("Video Preview", isOn: $storage.videoPreview)
				if storage.videoPreview {
					Toggle("Preview with sound", isOn: $storage.videoPreviewWithSound)
				}
			}
			#endif
			Section("User") {
				Button {
					dismiss()
					player.reset()
					api.logout()
				} label: {
					Text("Logout")
				}
				.disabled(!api.isLoggedIn)
			}
		}
	}
}


extension View {
	func settingsSheet() -> some View {
		self.modifier(SettingsSheet())
	}
}

fileprivate struct SettingsSheet: ViewModifier {
	@State private var showSettings = false
	
	func body(content: Content) -> some View {
		content
			#if os(iOS)
			.toolbar {
				ToolbarItem(placement: .primaryAction) {
					Button {
						showSettings = true
					} label: {
						Label("Settings", systemImage: "gear")
					}
				}
			}
			.sheet(isPresented: $showSettings) {
				SettingsView()
			}
			#endif
	}
}

#Preview {
	@Previewable @State var api = API()
	@Previewable @State var player = Player(api: API())
	@Previewable @State var storage = Storage()
	
	SettingsView()
		.environment(api)
		.environment(player)
		.environment(storage)
}
