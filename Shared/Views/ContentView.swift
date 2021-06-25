//
//  ContentView.swift
//  Shared
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct ContentView: View {
	@StateObject var model = Model()
	
    var body: some View {
		TabView {
			Featured()
				.tabItem { Label("Featured", systemImage: "star.circle") }
				.tag(Tabs.featured)
			MyShows()
				.tabItem { Label("My Shows", systemImage: "suit.heart") }
				.tag(Tabs.myShows)
			Text("Browse")
				.tabItem { Label("Browse", systemImage: "list.dash") }
				.tag(Tabs.browse)
			Text("Downloads")
				.tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
				.tag(Tabs.downloads)
			Text("Search")
				.tabItem { Label("Search", systemImage: "magnifyingglass") }
				.tag(Tabs.myShows)
		}
		.task {
			await model.setup()
		}
    }
}

extension ContentView {
	enum Tabs {
		case featured
		case myShows
		case browse
		case downloads
		case search
	}
}

extension ContentView {
	class Model: ObservableObject {
		func setup() async {
			do {
				let config = try await API.config()
				Settings.shared.nebulaAuthApi = config.authBaseUrl.absoluteString
				Settings.shared.nebulaContentApi = config.contentBaseUrl.absoluteString
			} catch {
				show(error: error)
			}
		}
		
		func show(error: Error) {
			print("Something went wrong:\n\(error)")
		}
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
