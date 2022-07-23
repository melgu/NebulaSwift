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
			ToolbarItemGroup(placement: .navigationBarTrailing) {
				if let following = following {
					if following {
						AsyncButton("Unfollow") {
							try await api.unfollow(channel)
							self.following = false
							await refresh?()
						}
					} else {
						AsyncButton("Follow") {
							try await api.follow(channel)
							self.following = true
							await refresh?()
						}
					}
				}
				ShareLink(item: channel.shareUrl)
			}
		}
		#endif
		.onAppear { player.reset() }
		.userActivity("de.melgu.NebulaSwift.channel") { activity in
			activity.title = channel.title
			try! activity.setTypedPayload(channel)
			activity.webpageURL = channel.shareUrl
		}
	}
}

struct ChannelPage_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
