//
//  Settings.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 04.04.22.
//

import SwiftUI

struct SettingsView: View {
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		#if os(iOS)
		NavigationStack {
			content
			.navigationTitle("Settings")
			.toolbar {
				ToolbarItem(placement: .primaryAction) {
					Button {
						dismiss()
					} label: {
						Label("Close", systemImage: "xmark.circle.fill")
					}
				}
			}
		}
		#else
		content
		#endif
	}
	
	private var content: some View {
		List {
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
