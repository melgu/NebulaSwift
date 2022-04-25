//
//  VideoGrid.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import SwiftUI

struct VideoGrid: View {
	let videos: [Video]
	var disableChannelNavigation = false
	
	@EnvironmentObject private var api: API
	
	@State private var channelInNavigation: Channel?
	
	var body: some View {
		ScrollView {
			LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), alignment: .top)]) {
				ForEach(videos) { video in
					VideoPreview(video: video, showChannelBlock: disableChannelNavigation ? nil : showChannel)
				}
			}
			.padding()
		}
		.navigation(item: $channelInNavigation) { channel in
			ChannelPage(channel: channel)
		}
	}
	
	func showChannel(slug: String) {
		Task {
			do {
				channelInNavigation = try await api.channel(for: slug)
			} catch {
				print(error)
			}
		}
	}
}

/// Auto-loading VideoGrid
struct AutoVideoGrid: View {
	let fetch: (Int) async throws -> [Video]
	let disableChannelNavigation: Bool
	
	@EnvironmentObject private var api: API
	
	@State private var videos: [Video] = []
	@State private var page = 1
	@State private var channelInNavigation: Channel?
	
	/// Auto-loading VideoGrid
	/// - Parameter fetch: Closure which loads the videos for a given page (1-indexed)
	init(fetch: @escaping (Int) async throws -> [Video], disableChannelNavigation: Bool = false) {
		self.fetch = fetch
		self.disableChannelNavigation = disableChannelNavigation
	}
	
	var body: some View {
		ScrollView {
			LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), alignment: .top)]) {
				ForEach(videos) { video in
					VideoPreview(video: video, showChannelBlock: disableChannelNavigation ? nil : showChannel)
						.task {
							if video == videos.last {
								print("Last video did appear, loading next page")
								do {
									videos += try await fetch(page + 1)
									page += 1
								} catch {
									print(error)
								}
							}
						}
				}
			}
			.padding()
		}
		.refreshable {
			print("Refresh Videos")
			await refreshVideos(animated: true)
		}
		.task {
			print("Load Videos")
			await refreshVideos()
		}
		.navigation(item: $channelInNavigation) { channel in
			ChannelPage(channel: channel)
		}
	}
	
	func refreshVideos(animated: Bool = false) async {
		do {
			let newVideos = try await fetch(1)
			if newVideos != videos {
				print("Video list changed")
				page = 1
				if animated {
					withAnimation {
						videos = newVideos
					}
				} else {
					videos = newVideos
				}
			}
		} catch {
			print(error)
		}
	}
	
	func showChannel(slug: String) {
		Task {
			do {
				channelInNavigation = try await api.channel(for: slug)
			} catch {
				print(error)
			}
		}
	}
}

struct VideoGrid_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
