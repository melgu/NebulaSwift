//
//  Search.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct Search: View {
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
	@State private var searchTerm = ""
	@State private var channelResults: [Channel] = []
	@State private var videoResults: [Video] = []
	@State private var task: Task<(), Never>?
	
    var body: some View {
		ScrollView {
			VStack(alignment: .leading) {
				TextField("Search", text: $searchTerm) {
					task?.cancel()
					channelResults.removeAll()
					videoResults.removeAll()
					task = Task {
						do {
							async let channels = api.searchChannels(for: searchTerm)
							async let videos = api.searchVideos(for: searchTerm)
							let both = try await (channels: channels, videos: videos)
							try Task.checkCancellation()
							channelResults = both.channels
							videoResults = both.videos
						} catch {
							print(error)
						}
					}
					Task { await task?.value }
				}
				.textFieldStyle(.roundedBorder)
				
				if !channelResults.isEmpty {
					Text("Channels")
						.font(.title)
					ChannelGrid(channels: channelResults)
				}
				if !channelResults.isEmpty && !videoResults.isEmpty {
					Divider()
				}
				if !videoResults.isEmpty {
					Text("Videos")
						.font(.title)
					VideoGrid(videos: videoResults)
				}
			}
			.padding()
		}
		.navigationTitle("Search")
		.onAppear { player.reset() }
    }
}

struct Search_Previews: PreviewProvider {
	private static let api = API()
	
    static var previews: some View {
        Search()
			.environmentObject(api)
			.environmentObject(Player(api: api))
    }
}
