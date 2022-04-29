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
	
	@Environment(\.dismiss) var dismiss
	
	var body: some View {
		#if os(iOS)
		NavigationView {
			content
			.navigationTitle("Settings")
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
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
	
	var content: some View {
		List {
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


extension View {
	func settingsSheet() -> some View {
		self.modifier(SettingsSheet())
	}
}

struct SettingsSheet: ViewModifier {
	@State private var showSettings = false
	
	func body(content: Content) -> some View {
		content
		#if os(iOS)
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
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
