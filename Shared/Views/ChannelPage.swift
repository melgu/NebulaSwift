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
	
	var body: some View {
		AutoVideoGrid(fetch: { page in
			try await api.videos(for: channel, page: page)
		}, disableChannelNavigation: true)
		.navigationTitle(channel.title)
		#if canImport(UIKit)
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				ShareButton(items: [channel.shareUrl]) {
					Image(systemName: "square.and.arrow.up")
				}
			}
		}
		#endif
		.onAppear {
			player.reset()
		}
	}
}

struct ChannelPage_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
