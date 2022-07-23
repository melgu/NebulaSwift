//
//  Featured.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct Featured: View {
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
	@State private var featured: [Feature] = []
	
	var body: some View {
		ScrollView(.vertical) {
			VStack(alignment: .leading, spacing: 32) {
				ForEach(featured) { feature in
					row(for: feature)
				}
			}
		}
		.refreshable {
			try await refreshFeatured()
		}
		.navigationTitle("Featured")
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				refreshButton
			}
		}
		.task {
			player.reset()
			try await refreshFeatured()
		}
    }
	
	@ViewBuilder
	private func row(for feature: Feature) -> some View {
		ScrollView(.horizontal) {
			VStack(alignment: .leading) {
				switch feature.items {
				case .heroes(_):
					EmptyView()
				default:
					Text(feature.title)
						.font(.title)
						.bold()
						.padding(.horizontal)
				}
				
				HStack(alignment: .top) {
					switch feature.items {
					case .heroes(let array):
						ForEach(array) { item in
							HeroPreview(hero: item)
								.frame(width: 480)
						}
					case .latestVideos(let array):
						ForEach(array) { item in
							VideoPreview(video: item)
								.frame(width: 240)
						}
					case .videoChannels(let array):
						ForEach(array) { item in
							ChannelPreview(channel: item)
								.frame(width: 240)
						}
					case .featuredCreators(let array):
						ForEach(array) { item in
							ChannelPreview(channel: item)
								.frame(width: 240)
						}
					case .podcastChannels(let array):
						ForEach(array) { item in
							PodcastPreview(podcast: item)
								.frame(width: 200)
						}
					}
				}
				.padding()
			}
		}
	}
	
	private var refreshButton: some View {
		AsyncButton {
			try await refreshFeatured()
		} label: {
			Image(systemName: "arrow.clockwise")
		}
		.asyncButtonStyle(.progress(replacesLabel: true))
	}
	
	private func refreshFeatured() async throws {
		let featured = try await api.featured()
		if featured != self.featured {
			withAnimation {
				self.featured = featured
			}
		}
	}
}

struct Featured_Previews: PreviewProvider {
	private static let api = API()
	
    static var previews: some View {
        Featured()
			.environmentObject(api)
			.environmentObject(Player(api: api))
    }
}
