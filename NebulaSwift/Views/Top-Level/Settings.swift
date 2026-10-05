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

	@State private var showLogoutConfirmation = false

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
			Section("General") {
				if #available(iOS 18, macOS 15, *) {
					// The default squeezes the icon of the current value against its title,
					// and the menu button drops icons from a custom label, so show only the title.
					Picker("Start Page", selection: $storage.startPage) {
						startPageOptions
					} currentValueLabel: {
						Text(storage.startPage.title)
					}
				} else {
					Picker("Start Page", selection: $storage.startPage) {
						startPageOptions
					}
				}
			}
			Section("Playback") {
				#if os(iOS) // No way to automatically enter fullscreen on macOS (without crashing the OS)
				Toggle("Automatic Fullscreen", isOn: $storage.automaticFullscreen)
				Toggle("Video Preview", isOn: $storage.videoPreview)
				if storage.videoPreview {
					Toggle("Preview with sound", isOn: $storage.videoPreviewWithSound)
				}
				#endif
				Toggle("Remove from Watch Later after playback", isOn: $storage.removeFromWatchLaterAfterPlayback)
			}
			Section("Appearance") {
				Stepper("Preview title lines: \(storage.previewTitleLines)", value: $storage.previewTitleLines, in: 1...3)
			}
			Section("User") {
				Button(role: .destructive) {
					showLogoutConfirmation = true
				} label: {
					Text("Logout")
				}
				.disabled(!api.isLoggedIn)
				.confirmationDialog("Do you really want to log out?", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
					Button("Logout", role: .destructive) {
						dismiss()
						player.reset()
						api.logout()
					}
				}
			}
		}
		// On a section, the modifier only reaches its rows, which can't animate their own insertion
		.animation(.default, value: storage.videoPreview)
	}

	private var startPageOptions: some View {
		ForEach(StartPage.allCases) { page in
			Label(page.title, systemImage: page.systemImage)
				.tag(page)
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
	@Previewable @State var player = Player(api: API(), storage: Storage())
	@Previewable @State var storage = Storage()
	
	SettingsView()
		.environment(api)
		.environment(player)
		.environment(storage)
}
