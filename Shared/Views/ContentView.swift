//
//  ContentView.swift
//  Shared
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI
import Combine

struct ContentView: View {
	@State private var tab: Tab = .myShows
	
    var body: some View {
		TabView(selection: $tab) {
			Featured()
				.tabItem { Label("Featured", systemImage: "star.circle") }
				.tag(Tab.featured)
			MyShows()
				.tabItem { Label("My Shows", systemImage: "suit.heart") }
				.tag(Tab.myShows)
			Browse()
				.tabItem { Label("Browse", systemImage: "list.dash") }
				.tag(Tab.browse)
			Downloads()
				.tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
				.tag(Tab.downloads)
			Search()
				.tabItem { Label("Search", systemImage: "magnifyingglass") }
				.tag(Tab.search)
		}
    }
}

extension ContentView {
	enum Tab {
		case featured
		case myShows
		case browse
		case downloads
		case search
	}
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
