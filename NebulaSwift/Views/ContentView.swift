//
//  ContentView.swift
//  Shared
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI
import Combine
import Network
import OSLog

private let logger = Logger(category: "ContentView")

struct ContentView: View {
	@Environment(API.self) private var api
	@Environment(Player.self) private var player

	@State private var myShows: [Channel]?
	/// Why the channels couldn't be loaded initially, shown in their place until a load succeeds.
	@State private var myShowsError: Error?
	
	@State private var selection: TopLevel? = TopLevel(StartPage.saved)
	private enum TopLevel: Hashable {
		case featured, myShows, browse, watchLater, downloads, search, channel(Channel)

		init(_ page: StartPage) {
			switch page {
			case .featured: self = .featured
			case .myShows: self = .myShows
			case .browse: self = .browse
			case .watchLater: self = .watchLater
			case .downloads: self = .downloads
			}
		}
	}
	
	@State private var searchTerm = ""
	
	@State private var navigationPath = NavigationPath()
	@State private var playerVideo: Video?
	/// The video playing in Picture in Picture while its page is closed.
	@State private var pictureInPictureVideo: Video?
	@State private var playerDismissalCount = 0

	var body: some View {
		Group {
			if api.isLoggedIn {
				NavigationSplitView {
					sidebar
						#if os(macOS)
						.frame(minWidth: 200)
						#endif
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
				openVideo(video)
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
					openVideo(video)
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
				openVideo(video)
			} else {
				logger.debug("Continue User Activity. Video URL: \(activity.webpageURL?.absoluteString ?? "nil")")
				Task {
					guard let url = activity.webpageURL else { return }
					let slug = url.lastPathComponent
					guard !slug.isEmpty else { return }
					let video = try await api.video(for: slug)
					openVideo(video)
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
		.onChange(of: player.isPictureInPictureActive) { _, isActive in
			if isActive {
				// Keep playing in Picture in Picture while browsing
				guard let video = playerVideo else { return }
				logger.debug("Close player for Picture in Picture")
				pictureInPictureVideo = video
				playerVideo = nil
			} else if pictureInPictureVideo != nil {
				// Picture in Picture was closed without going back to the video
				logger.debug("Picture in Picture closed")
				pictureInPictureVideo = nil
				player.reset()
				playerDidDismiss()
			}
		}
		.onChange(of: player.pictureInPictureRestore) { _, restore in
			guard let restore else { return }
			if pictureInPictureVideo != nil {
				logger.debug("Restore player from Picture in Picture")
				pictureInPictureVideo = nil
				playerVideo = restore.video
			} else {
				// The page is still open, or another video replaces it
				player.completePictureInPictureRestore()
			}
		}
		.task {
			await showDownloadsIfOffline()
		}
		.alertErrorHandling()
	}
	
	/// Opens the downloads instead of the start page when the app opens without a connection, since they're all that works then.
	private func showDownloadsIfOffline() async {
		let startPage = selection
		let isConnected = await withCheckedContinuation { continuation in
			let monitor = NWPathMonitor()
			monitor.pathUpdateHandler = { path in
				// Only the first update matters
				monitor.pathUpdateHandler = nil
				monitor.cancel()
				continuation.resume(returning: path.status == .satisfied)
			}
			monitor.start(queue: DispatchQueue(label: "de.melgu.NebulaSwift.ConnectionCheck"))
		}
		// Unless another page was picked meanwhile
		guard !isConnected, selection == startPage else { return }
		logger.log("Offline at launch, show downloads")
		selection = .downloads
	}

	private func openVideo(_ video: Video) {
		if pictureInPictureVideo != nil {
			logger.debug("Stop Picture in Picture for another video")
			pictureInPictureVideo = nil
			player.stopPiP()
		}
		playerVideo = video
	}
	
	private var sidebar: some View {
		List(selection: $selection) {
			if searchTerm.isEmpty {
				Section("Home") {
					ForEach(StartPage.allCases) { page in
						NavigationLink(value: TopLevel(page)) {
							Label(page.title, systemImage: page.systemImage)
						}
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
			} else if let myShowsError {
				Section("My Shows") {
					LoadingErrorView(error: myShowsError) {
						Task { await loadMyShows() }
					}
				}
			} else {
				Section("My Shows") {
					ProgressView()
						.controlSize(.large)
						.frame(maxWidth: .infinity)
						.listRowBackground(Color.clear)
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
			await loadMyShows()
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
			.fullScreenCover(item: $playerVideo, onDismiss: playerDidDismiss) { video in
				VideoPage(video: video)
			}
			#else
			.sheet(item: $playerVideo, onDismiss: playerDidDismiss) { video in
				VideoPage(video: video)
					.frame(idealWidth: 760, idealHeight: 640)
			}
			#endif
		}
		.environment(\.playerDismissalCount, playerDismissalCount)
	}

	private func playerDidDismiss() {
		Task {
			// The refresh should already see the progress and Watch Later changes from playback.
			await player.waitForPendingUpdates()
			playerDismissalCount += 1
		}
	}

	/// Loads the channels for the first time, showing a failure in their place instead of an alert.
	private func loadMyShows() async {
		myShowsError = nil
		do {
			try await refreshMyShows()
		} catch {
			guard !error.isCancellation else { return }
			logger.error("Loading My Shows failed. Error: \(error)")
			myShowsError = error
		}
	}

	private func refreshMyShows() async throws {
		myShows = try await api.libraryChannels(page: 1, pageSize: 200)
		myShowsError = nil
	}
	
	private func label(for channel: Channel) -> some View {
		HStack {
			AsyncImage(url: channel.images.avatar[64]) { image in
				image
					.resizable()
					.scaledToFit()
					.clipShape(Circle())
			} placeholder: {
				Color.clear
			}
			.frame(width: 32, height: 32)
			.accessibilityHidden(true)
			
			Text(channel.title)
				.lineLimit(1)
		}
	}
}

struct ContentView_Previews: PreviewProvider {
	private static let api = API()
	
	static var previews: some View {
		ContentView()
			.environment(api)
			.environment(Player(api: api, storage: Storage(), downloads: DownloadManager(api: api, storage: Storage())))
	}
}
