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
	
	var body: some View {
		AutoVideoGrid(fetch: { page in
			try await api.videos(for: channel, page: page)
		})
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
	}
}

struct ChannelPage_Previews: PreviewProvider {
    static var previews: some View {
        Text("No preview")
    }
}
