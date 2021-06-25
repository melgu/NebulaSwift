//
//  NebulaSwiftApp.swift
//  Shared
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

@main
struct NebulaSwiftApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
		#if os(macOS)
		.windowStyle(.hiddenTitleBar)
		#endif
    }
}
