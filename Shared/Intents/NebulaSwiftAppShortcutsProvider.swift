//
//  NebulaSwiftAppShortcutsProvider.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 12.06.23.
//

import Foundation
import AppIntents

struct NebulaSwiftAppShortcutsProvider: AppShortcutsProvider {
	static var appShortcuts: [AppShortcut] {
		AppShortcut(
			intent: ShowChannel(),
			phrases: [
				"Show \(.applicationName) channel",
				"Show channel in \(.applicationName)",
				"Show \(\.$channel) in \(.applicationName)"
			],
			shortTitle: "Show Channel",
			systemImageName: "person.crop.rectangle"
			// TODO: Parameter presentation?
		)
	}
}
