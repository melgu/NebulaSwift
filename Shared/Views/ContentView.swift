//
//  ContentView.swift
//  Shared
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI
import Combine
import AVKit

struct ContentView: View {
	@Environment(\.player) private var player
	
	#if canImport(UIKit)
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	#endif
	
	@State private var tab: Tab? = .myShows
	
	var body: some View {
		Group {
			#if os(iOS)
			if horizontalSizeClass == .compact {
				tabView
			} else {
				list
			}
			#else
			list
			#endif
		}
		.onChange(of: tab) { newValue in
			print("Tab changed")
			player.replaceCurrentItem(with: nil)
		}
	}
	
	var list: some View {
		NavigationView {
			List {
				NavigationLink(tag: Tab.featured, selection: $tab) {
					Featured()
				} label: {
					Label("Featured", systemImage: "star.circle")
				}
				NavigationLink(tag: Tab.myShows, selection: $tab) {
					MyShows()
				} label: {
					Label("My Shows", systemImage: "suit.heart")
				}
				NavigationLink(tag: Tab.browse, selection: $tab) {
					Browse()
				} label: {
					Label("Browse", systemImage: "list.dash")
				}
				NavigationLink(tag: Tab.downloads, selection: $tab) {
					Downloads()
				} label: {
					Label("Downloads", systemImage: "arrow.down.circle")
				}
				NavigationLink(tag: Tab.search, selection: $tab) {
					Search()
				} label: {
					Label("Search", systemImage: "magnifyingglass")
				}
			}
			.listStyle(.sidebar)
			.navigationTitle("Nebula")
		}
	}
	
	var tabView: some View {
		TabView(selection: $tab) {
			NavigationView {
				Featured()
			}
			.tabItem { Label("Featured", systemImage: "star.circle") }
			.tag(Tab.featured)
			
			NavigationView {
				MyShows()
			}
			.tabItem { Label("My Shows", systemImage: "suit.heart") }
			.tag(Tab.myShows)
			
			NavigationView {
				Browse()
			}
			.tabItem { Label("Browse", systemImage: "list.dash") }
			.tag(Tab.browse)
			
			NavigationView {
				Downloads()
			}
			.tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
			.tag(Tab.downloads)
			
			NavigationView {
				Search()
			}
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
