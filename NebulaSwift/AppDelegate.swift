//
//  AppDelegate.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 10.10.26.
//

#if os(macOS)
import AppKit

@Observable
final class AppDelegate: NSObject, NSApplicationDelegate {
	/// The channels in My Shows, for the Dock menu. Set by the sidebar whenever it loads them.
	var myShows: [Channel]?

	func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
		let menu = NSMenu()
		for page in StartPage.allCases {
			menu.addItem(item(title: String(localized: page.title), systemImage: page.systemImage, url: "NebulaSwift://page/\(page.rawValue)"))
		}
		menu.addItem(item(title: String(localized: "Search"), systemImage: "magnifyingglass", url: "NebulaSwift://search"))

		if let myShows, !myShows.isEmpty {
			let channels = NSMenu()
			for channel in myShows {
				channels.addItem(item(title: channel.title, systemImage: nil, url: "NebulaSwift://channel/\(channel.slug)"))
			}
			// Not "My Shows" like the sidebar section, which would be the same title as the page above
			let channelsItem = NSMenuItem(title: String(localized: "My Channels"), action: nil, keyEquivalent: "")
			channelsItem.image = NSImage(systemSymbolName: "person.2", accessibilityDescription: nil)
			channelsItem.submenu = channels
			menu.addItem(.separator())
			menu.addItem(channelsItem)
		}
		return menu
	}

	private func item(title: String, systemImage: String?, url: String) -> NSMenuItem {
		let item = NSMenuItem(title: title, action: #selector(open(_:)), keyEquivalent: "")
		item.target = self
		item.representedObject = URL(string: url)
		if let systemImage {
			item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)
		}
		return item
	}

	/// Goes through the URL handling, which also opens a window if none is open.
	@objc private func open(_ sender: NSMenuItem) {
		guard let url = sender.representedObject as? URL else { return }
		NSWorkspace.shared.open(url)
	}
}
#endif
