//
//  NebulaSwiftApp.swift
//  Shared
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

@main
struct NebulaSwiftApp: App {
	@StateObject var model = Model()
	
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
		#if os(macOS)
		.windowStyle(.hiddenTitleBar)
		#endif
		.commands {
			CommandMenu("Account") {
				Button("Logout", action: model.logout)
			}
		}
    }
}

extension NebulaSwiftApp {
	class Model: ObservableObject {
		func logout() {
			Settings.shared.clearAll()
		}
	}
}
