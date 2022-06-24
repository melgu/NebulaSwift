//
//  ContentView.swift
//  Shared
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI
import Combine

struct ContentView: View {
	@EnvironmentObject private var api: API
	
	#if canImport(UIKit)
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	#endif
	
	@State private var myShows: [Channel]?
	
	@State private var selection: TopLevel? = .myShows
	private enum TopLevel: Hashable {
		case featured, myShows, browse, watchLater, downloads, search, channel(Channel)
	}
	
	@State private var navigationPath = NavigationPath()
	
	var body: some View {
		Group {
			if api.isLoggedIn {
				NavigationSplitView {
					sidebar
				} detail: {
					detail
				}
			} else {
				Login()
			}
		}
		.alertErrorHandling()
	}
	
	private var sidebar: some View {
		List(selection: $selection) {
			Section("Home") {
				NavigationLink(value: TopLevel.featured) {
					Label("Featured", systemImage: "star.circle")
				}
				NavigationLink(value: TopLevel.myShows) {
					Label("My Shows", systemImage: "suit.heart")
				}
				NavigationLink(value: TopLevel.browse) {
					Label("Browse", systemImage: "list.dash")
				}
				NavigationLink(value: TopLevel.watchLater) {
					Label("Watch Later", systemImage: "bookmark")
				}
				NavigationLink(value: TopLevel.downloads) {
					Label("Downloads", systemImage: "arrow.down.circle")
				}
				NavigationLink(value: TopLevel.search) {
					Label("Search", systemImage: "magnifyingglass")
				}
			}
			if let myShows = myShows {
				Section("My Shows") {
					ForEach(myShows) { channel in
						NavigationLink(value: TopLevel.channel(channel)) {
							label(for: channel)
						}
						.contextMenu(for: channel)
					}
				}
			}
		}
		.refreshable {
			try await refreshMyShows()
		}
		.listStyle(.sidebar)
		.navigationTitle("Nebula")
		.task {
			try await refreshMyShows()
		}
		.settingsSheet()
	}
	
	private var detail: some View {
		NavigationStack(path: $navigationPath) {
			ZStack { // Workaround for Beta bug (No updates on selection change, FB91311311)
				switch selection {
				case .featured:
					Featured()
				case .myShows:
					MyShows()
				case .browse:
					Browse()
				case .watchLater:
					WatchLater()
				case .downloads:
					Downloads()
				case .search:
					Search()
				case .channel(let channel):
					ChannelPage(channel: channel)
				case nil:
					Text("NebulaSwift")
				}
			}
			.navigationDestination(for: Channel.self) { channel in
				ChannelPage(channel: channel)
			}
			.environment(\.openItem) { item in
				navigationPath.append(item)
			}
		}
	}
	
	private func refreshMyShows() async throws {
		myShows = try await api.libraryChannels(page: 1, pageSize: 200)
	}
	
	private func label(for channel: Channel) -> some View {
		HStack {
			AsyncImage(url: channel.assets.avatar["64"]?.original) { image in
				image
					.resizable()
					.scaledToFit()
					.clipShape(Circle())
			} placeholder: {
				Color.clear
			}
			.frame(width: 32, height: 32)
			
			Text(channel.title)
				.lineLimit(1)
		}
	}
}

struct ContentView_Previews: PreviewProvider {
    private static let api = API()
    
    static var previews: some View {
        ContentView()
            .environmentObject(api)
            .environmentObject(Player(api: api))
    }
}
