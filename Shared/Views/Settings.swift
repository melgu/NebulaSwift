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
			
			Section("Third-Party-Licenses") {
				NavigationLink("SwiftUIPullToRefresh") {
					ScrollView {
						Text(
							"""
							MIT License

							Copyright (c) 2021 Gordan Glavaš

							Permission is hereby granted, free of charge, to any person obtaining a copy
							of this software and associated documentation files (the "Software"), to deal
							in the Software without restriction, including without limitation the rights
							to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
							copies of the Software, and to permit persons to whom the Software is
							furnished to do so, subject to the following conditions:

							The above copyright notice and this permission notice shall be included in all
							copies or substantial portions of the Software.

							THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
							IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
							FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
							AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
							LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
							OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
							SOFTWARE.
							"""
						)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding()
					}
					.navigationTitle("SwiftUIPullToRefresh")
				}
			}
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
