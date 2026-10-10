//
//  QuickAction.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 10.10.26.
//

import Foundation

/// A Home Screen quick action, opening a page of the sidebar.
enum QuickAction: Codable, Hashable, Identifiable {
	case page(StartPage)
	case search
	/// Keeps the title, so the action stays the same after unfollowing the channel.
	case channel(slug: String, title: String)

	/// The most the Home Screen shows.
	static let limit = 4

	static let defaults: [QuickAction] = [.page(.continueWatching), .page(.watchLater), .page(.downloads), .search]

	init(_ channel: Channel) {
		self = .channel(slug: channel.slug, title: channel.title)
	}

	var id: URL { url }

	/// Opens the action through the URL handling.
	var url: URL {
		switch self {
		case .page(let page): URL(string: "NebulaSwift://page/\(page.rawValue)")!
		case .search: URL(string: "NebulaSwift://search")!
		case .channel(let slug, _): URL(string: "NebulaSwift://channel/\(slug)")!
		}
	}

	var title: String {
		switch self {
		case .page(let page): String(localized: page.title)
		case .search: String(localized: "Search")
		case .channel(_, let title): title
		}
	}

	var systemImage: String {
		switch self {
		case .page(let page): page.systemImage
		case .search: "magnifyingglass"
		case .channel: "person.crop.circle"
		}
	}
}
