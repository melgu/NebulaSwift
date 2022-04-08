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
	
    var body: some View {
		ScrollView {
			VStack(alignment: .leading) {
				TextField("Search", text: $searchTerm) {
					Task {
						do {
							channelResults = try await api.searchChannels(for: searchTerm)
							videoResults = try await api.searchVideos(for: searchTerm)
						} catch {
							print(error)
						}
					}
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
		.onAppear {
			player.reset()
		}
    }
}

struct Search_Previews: PreviewProvider {
    static var previews: some View {
        Search()
    }
}
