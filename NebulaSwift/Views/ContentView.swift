//
//  ContentView.swift
//  Shared
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI
import Combine
import OSLog

private let logger = Logger(category: "ContentView")

struct ContentView: View {
	@EnvironmentObject private var api: API
	
	@State private var myShows: [Channel]?
	
	@State private var selection: TopLevel? = .myShows
	private enum TopLevel: Hashable {
		case featured, myShows, browse, watchLater, downloads, search, channel(Channel)
	}
	
	@State private var searchTerm = ""
	
	@State private var navigationPath = NavigationPath()
	@State private var playerVideo: Video?
	
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
		.onOpenItem { item in
			logger.debug("Open Item: \(String(describing: item))")
			if let video = item as? Video {
				playerVideo = video
			} else {
				navigationPath.append(item)
			}
		}
		.onOpenURL { url in
			logger.debug("Open URL: \(url)")
			Task {
				switch url.host() {
				case "video":
					// nebulaswift://video/slug
					guard let slug = url.pathComponents.last else { return }
					let video = try await api.video(for: slug)
					playerVideo = video
				case "channel":
					// nebulaswift://channel/slug
					guard let slug = url.pathComponents.last else { return }
					let channel = try await api.channel(for: slug)
					navigationPath.append(channel)
				default:
					logger.debug("Unknown type: \(url.host() ?? "nil")")
				}
			}
		}
		.onContinueUserActivity("de.melgu.NebulaSwift.video") { activity in
			if let video = try? activity.typedPayload(Video.self) {
				logger.debug("Continue User Activity. Video: \(video.title)")
				playerVideo = video
			} else {
				logger.debug("Continue User Activity. Video URL: \(activity.webpageURL?.absoluteString ?? "nil")")
				Task {
					guard let url = activity.webpageURL else { return }
					let slug = url.lastPathComponent
					guard !slug.isEmpty else { return }
					let video = try await api.video(for: slug)
					playerVideo = video
				}
			}
		}
		.onContinueUserActivity("de.melgu.NebulaSwift.channel") { activity in
			if let channel = try? activity.typedPayload(Channel.self) {
				logger.debug("Continue User Activity. Channel: \(channel.title)")
				if let channel = myShows?.first(where: { $0.slug == channel.slug }) {
					selection = .channel(channel)
				} else {
					navigationPath.append(channel)
				}
			} else {
				logger.debug("Continue User Activity. Channel URL: \(activity.webpageURL?.absoluteString ?? "nil")")
				guard let url = activity.webpageURL else { return }
				let slug = url.lastPathComponent
				guard !slug.isEmpty else { return }
				if let channel = myShows?.first(where: { $0.slug == slug }) {
					selection = .channel(channel)
				} else {
					Task {
						let channel = try await api.channel(for: slug)
						navigationPath.append(channel)
					}
				}
			}
		}
		.alertErrorHandling()
	}
	
	private var sidebar: some View {
		List(selection: $selection) {
			if searchTerm.isEmpty {
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
			}
			if let filteredMyShows {
				Section("My Shows") {
					ForEach(filteredMyShows) { channel in
						NavigationLink(value: TopLevel.channel(channel)) {
							label(for: channel)
								.draggable(channel.shareUrl)
						}
						.contextMenu(for: channel)
					}
				}
			}
		}
		.searchable(text: $searchTerm, placement: .sidebar, prompt: Text("Search My Shows"))
		.autocorrectionDisabled()
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
	
	private var filteredMyShows: [Channel]? {
		guard let myShows else { return nil }
		guard !searchTerm.isEmpty else { return myShows }
		return myShows.filter { $0.title.lowercased().contains(searchTerm.lowercased()) }
	}
	
	private var detail: some View {
		NavigationStack(path: $navigationPath) {
			Group {
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
			#if os(iOS)
			.fullScreenCover(item: $playerVideo) { video in
				VideoPage(video: video)
			}
			#else
			.sheet(item: $playerVideo) { video in
				VideoPage(video: video)
					.frame(idealWidth: 760, idealHeight: 640)
			}
			#endif
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
