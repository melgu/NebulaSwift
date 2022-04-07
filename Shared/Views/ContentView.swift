//
//  ContentView.swift
//  Shared
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI
import Combine

struct ContentView: View {
	@EnvironmentObject private var player: Player
	@EnvironmentObject private var api: API
	
	#if canImport(UIKit)
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	#endif
	
	@State private var myShows: [Channel]?
	
	var body: some View {
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
	
	var list: some View {
		NavigationView {
			List {
				Section("Nebula") {
					NavigationLink {
						Featured()
					} label: {
						Label("Featured", systemImage: "star.circle")
					}
					NavigationLink {
						MyShows()
					} label: {
						Label("My Shows", systemImage: "suit.heart")
					}
					NavigationLink {
						Browse()
					} label: {
						Label("Browse", systemImage: "list.dash")
					}
					NavigationLink {
						Downloads()
					} label: {
						Label("Downloads", systemImage: "arrow.down.circle")
					}
					NavigationLink {
						Search()
					} label: {
						Label("Search", systemImage: "magnifyingglass")
					}
				}
				if let myShows = myShows {
					Section("My Shows") {
						ForEach(myShows) { channel in
							NavigationLink {
								Text(channel.title)
							} label: {
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
					}
				}
			}
			.listStyle(.sidebar)
			.navigationTitle("Nebula")
			.task {
				do {
					myShows = try await api.libraryChannels(page: 1, pageSize: 200)
				} catch {
					print(error)
				}
			}
		}
	}
	
	var tabView: some View {
		TabView {
			NavigationView {
				Featured()
			}
			.tabItem { Label("Featured", systemImage: "star.circle") }
			
			NavigationView {
				MyShows()
			}
			.tabItem { Label("My Shows", systemImage: "suit.heart") }
			
			NavigationView {
				Browse()
			}
			.tabItem { Label("Browse", systemImage: "list.dash") }
			
			NavigationView {
				Downloads()
			}
			.tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
			
			NavigationView {
				Search()
			}
			.tabItem { Label("Search", systemImage: "magnifyingglass") }
		}
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
