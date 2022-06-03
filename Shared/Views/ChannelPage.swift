//
//  ChannelPage.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 07.04.22.
//

import SwiftUI

struct ChannelPage: View {
	let channel: Channel
	
	@EnvironmentObject private var api: API
	@EnvironmentObject private var player: Player
	
	@Environment(\.refresh) private var refresh
	
	@State private var following: Bool?
	
	init(channel: Channel) {
		self.channel = channel
		self._following = State(initialValue: channel.engagement?.following)
	}
	
	var body: some View {
		AutoVideoGrid(fetch: { page in
			try await api.videos(for: channel, page: page)
		})
		.disableGoToChannel()
		.navigationTitle(channel.title)
		#if canImport(UIKit)
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				if let following = following {
					if following {
						AsyncButton("Unfollow") {
							do {
								try await api.unfollow(channel)
								self.following = false
								await refresh?()
							} catch {
								print(error)
							}
						}
					} else {
						AsyncButton("Follow") {
							do {
								try await api.follow(channel)
								self.following = true
								await refresh?()
							} catch {
								print(error)
							}
						}
					}
				}
			}
			ToolbarItem(placement: .navigationBarTrailing) {
				ShareButton(items: [channel.shareUrl]) {
					Label("Share", systemImage: "square.and.arrow.up")
				}
			}
		}
		#endif
		.onAppear { player.reset() }
	}
}

struct ChannelPage_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
